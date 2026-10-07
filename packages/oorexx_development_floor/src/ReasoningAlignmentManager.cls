/* ReasoningAlignmentManager.cls
   Bounded management comparison between required reasoning obligations and a
   worker's claimed reasoning summary.

   The manager never requests or consumes private chain-of-thought.  It compares
   only an explicit claimed summary against Development Floor's own known work
   obligations.  The model supplies a score and gaps; Development Floor owns the
   threshold and computes MATCH/MISMATCH deterministically.
*/

::class DFReasoningAlignmentBuild public
::constant API_VERSION "development.floor.reasoning-alignment/0.1"
::constant DEFAULT_THRESHOLD 0.70
::constant MAX_TEXT_BYTES 32768
::constant MAX_GAPS 16

::class DFReasoningAlignmentOutcome public
::attribute ok get
::attribute code get
::attribute detail get
::attribute score get
::attribute verdict get
::attribute gaps get
::attribute inputTokens get
::attribute outputTokens get

::method init
  expose ok code detail score verdict gaps inputTokens outputTokens
  use strict arg okArg, codeArg, detailArg="", scoreArg=0, verdictArg="", gapsArg=.nil, inputArg=0, outputArg=0
  ok = okArg == .true
  code = codeArg~string
  detail = detailArg~string
  score = scoreArg
  verdict = verdictArg~string~upper
  if gapsArg == .nil then gaps = .Array~new
  else gaps = gapsArg
  inputTokens = inputArg
  outputTokens = outputArg

::class DFReasoningAlignmentManager public
::method init
  expose provider journal threshold
  use strict arg providerArg, journalArg=.nil, thresholdArg=0.70
  if providerArg == .nil then raise syntax 93.900 array("Reasoning alignment manager requires provider")
  if \providerArg~hasMethod("COMPLETE") then raise syntax 93.900 array("Reasoning alignment provider must implement complete(request)")
  if \datatype(thresholdArg, "N") then raise syntax 93.900 array("Reasoning alignment threshold must be numeric")
  if thresholdArg < 0 then raise syntax 93.900 array("Reasoning alignment threshold must be >= 0")
  if thresholdArg > 1 then raise syntax 93.900 array("Reasoning alignment threshold must be <= 1")
  provider = providerArg
  journal = journalArg
  threshold = thresholdArg

::method evaluate
  expose provider journal threshold
  use strict arg workItemId, requiredReasoning, claimedReasoning, modelId, maxOutputTokens=512
  if requiredReasoning~length > .DFReasoningAlignmentBuild~MAX_TEXT_BYTES then return .DFReasoningAlignmentOutcome~new(.false, "REQUIRED_REASONING_TOO_LARGE")
  if claimedReasoning~length > .DFReasoningAlignmentBuild~MAX_TEXT_BYTES then return .DFReasoningAlignmentOutcome~new(.false, "CLAIMED_REASONING_TOO_LARGE")
  if claimedReasoning~strip = "" then return .DFReasoningAlignmentOutcome~new(.false, "CLAIMED_REASONING_MISSING", "worker supplied no claimed reasoning summary")

  if journal \== .nil then do
    ignore = journal~persist("MANAGEMENT", "REQUIRED_REASONING", "management/required-reasoning.txt", requiredReasoning, workItemId)
    ignore = journal~persist("MANAGEMENT", "CLAIMED_REASONING", "management/claimed-reasoning.txt", claimedReasoning, workItemId)
  end
  prompt = self~comparisonPrompt(workItemId, requiredReasoning, claimedReasoning)
  if journal \== .nil then ignore = journal~persist("MANAGEMENT", "MODEL_REQUEST", "management/reasoning-evaluation.prompt.txt", prompt, workItemId)
  reply = provider~complete(.AIProviderRequest~new(modelId, prompt, maxOutputTokens))
  if journal \== .nil then ignore = journal~persist("MANAGEMENT", "MODEL_RESPONSE", "management/reasoning-evaluation.response.json", reply~text, "ok=" || reply~ok || " code=" || reply~code)
  if \reply~ok then return .DFReasoningAlignmentOutcome~new(.false, reply~code, reply~detail, 0, "", .nil, reply~usage~inputTokens, reply~usage~outputTokens)

  parsed = self~parseScore(reply~text)
  if \parsed[1] then return .DFReasoningAlignmentOutcome~new(.false, "REASONING_EVALUATION_INVALID", parsed[2], 0, "", .nil, reply~usage~inputTokens, reply~usage~outputTokens)
  score = parsed[3]
  gaps = parsed[4]
  if score >= threshold then verdict = "MATCH"
  else verdict = "MISMATCH"
  normalized = self~resultJson(workItemId, score, threshold, verdict, gaps)
  if journal \== .nil then ignore = journal~persist("MANAGEMENT", "REASONING_ALIGNMENT", "management/reasoning-evaluation.json", normalized, "score=" || score || " verdict=" || verdict)
  return .DFReasoningAlignmentOutcome~new(.true, "OK", "", score, verdict, gaps, reply~usage~inputTokens, reply~usage~outputTokens)

::method comparisonPrompt
  use strict arg workItemId, requiredReasoning, claimedReasoning
  text = "You are a bounded Development Floor management comparator." || "0a"x
  text ||= "Do not solve the coding task. Do not inspect private reasoning. Compare only the two supplied texts." || "0a"x
  text ||= "WORK_ITEM=" || workItemId || "0a"x
  text ||= "REQUIRED_REASONING_OBLIGATIONS:" || "0a"x || requiredReasoning || "0a"x
  text ||= "CLAIMED_REASONING_SUMMARY:" || "0a"x || claimedReasoning || "0a"x
  text ||= 'Return JSON only: {"score":<number from 0.0 through 1.0>,"gaps":["<short missing or mismatched obligation>"]}' || "0a"x
  text ||= "Score semantic coverage and consistency, not writing style. Empty gaps is allowed. No markdown. No extra fields."
  return text

::method parseScore
  use strict arg text
  signal on syntax name invalid
  data = .JSON~fromJSON(text)
  signal off syntax
  if \data~isa(.Directory) then return .Array~of(.false, "not-object")
  if data~items \= 2 then return .Array~of(.false, "unexpected-fields")
  scoreValue = data~at("score")
  gapsValue = data~at("gaps")
  if scoreValue == .nil then return .Array~of(.false, "score-missing")
  if \datatype(scoreValue~string, "N") then return .Array~of(.false, "score-not-numeric")
  score = scoreValue~string
  if score < 0 then return .Array~of(.false, "score-below-zero")
  if score > 1 then return .Array~of(.false, "score-above-one")
  if gapsValue == .nil then return .Array~of(.false, "gaps-missing")
  if \gapsValue~isa(.Array) then return .Array~of(.false, "gaps-not-array")
  if gapsValue~items > .DFReasoningAlignmentBuild~MAX_GAPS then return .Array~of(.false, "too-many-gaps")
  gaps = .Array~new
  do gap over gapsValue
    gapText = gap~string~strip
    if gapText = "" then return .Array~of(.false, "gap-empty")
    if gapText~length > 512 then return .Array~of(.false, "gap-too-long")
    gaps~append(gapText)
  end
  return .Array~of(.true, "", score, gaps)
invalid:
  say "Reasoning alignment JSON syntax failure rc=" rc "sigl=" sigl "conditionC=" condition("C") "conditionD=" condition("D")
  signal off syntax
  return .Array~of(.false, "invalid-json")

::method resultJson
  use strict arg workItemId, score, threshold, verdict, gaps
  text = '{"schema":"development.floor.reasoning-alignment/0.1"'
  text ||= ',"work_item":"' || self~jsonEscape(workItemId) || '"'
  text ||= ',"score":' || score
  text ||= ',"threshold":' || threshold
  text ||= ',"verdict":"' || verdict || '"'
  text ||= ',"gaps":['
  first = .true
  do gap over gaps
    if \first then text ||= ','
    text ||= '"' || self~jsonEscape(gap) || '"'
    first = .false
  end
  text ||= ']}' || "0a"x
  return text

::method jsonEscape
  use strict arg valueArg
  value = valueArg~string
  value = value~changestr('\\', '\\\\')
  value = value~changestr('"', '\\"')
  value = value~changestr("0d"x, '\\r')
  value = value~changestr("0a"x, '\\n')
  value = value~changestr("09"x, '\\t')
  return value

::requires "AIProviderAccess.cls"
::requires "json.cls"
