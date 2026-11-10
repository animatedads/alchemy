/* IntentionProviders.cls
 * Provider implementations for IntentionService.
 */

::class DeterministicIntentionProvider public
::method name
  return "DETERMINISTIC"

::method propose
  use arg service, text
  normalizedInput = self~normalize(text)
  proposals = .Array~new
  registrations = service~registrations
  supplier = registrations~supplier
  do while supplier~available
    registration = supplier~item
    bestScore = 0
    explicit = .false
    aliases = registration~aliases
    aliasIndex = 1
    do while aliasIndex <= aliases~items
      alias = self~normalize(aliases~at(aliasIndex))
      score = self~score(normalizedInput, alias)
      if score > bestScore then bestScore = score
      if pos(alias, normalizedInput) > 0 then explicit = .true
      aliasIndex = aliasIndex + 1
    end
    if bestScore > 0 then do
      proposal = .IntentionProposal~new(registration~id, bestScore, self~name, explicit, "deterministic phrase evidence")
      self~extractSlots(registration, text, proposal)
      proposals~append(proposal)
    end
    supplier~next
  end
  return proposals

::method normalize
  use arg text
  value = translate(strip(text))
  value = changestr("  ", value, " ")
  do while pos("  ", value) > 0
    value = changestr("  ", value, " ")
  end
  return value

::method score
  use arg input, alias
  if input == alias then return 100
  if pos(alias, input) > 0 then return 90
  words = 0
  matched = 0
  rest = alias
  do while rest \== ""
    parse var rest word rest
    if word == "" then iterate
    words = words + 1
    if wordpos(word, input) > 0 then matched = matched + 1
  end
  if words = 0 then return 0
  if matched = 0 then return 0
  return trunc((matched * 80) / words)

::method extractSlots
  use arg registration, text, proposal
  rules = registration~slotRules
  ruleIndex = 1
  do while ruleIndex <= rules~items
    rule = rules~at(ruleIndex)
    value = self~extractRule(rule, text)
    if value \== "" then proposal~putSlot(rule~slotName, value, .true)
    ruleIndex = ruleIndex + 1
  end
  return proposal

::method extractRule
  use arg rule, text
  upperText = translate(text)
  markers = rule~markers
  rest = markers
  do while rest \== ""
    parse var rest marker '|' rest
    marker = strip(marker)
    if marker == "" then iterate
    markerPos = wordpos(marker, upperText)
    if markerPos = 0 then iterate
    if rule~mode == "REST" then do
      words = upperText~space
      answer = ""
      do wordIndex = markerPos + 1 to words~words
        if answer == "" then answer = words~word(wordIndex)
        else answer = answer || " " || words~word(wordIndex)
      end
      return strip(answer)
    end
    return upperText~word(markerPos + 1)
  end
  return ""

/* Compatibility adapter for callers that already hold a configured
 * SymbolicNLPParser.  New code should prefer service~useNlp(), which selects
 * an NLP engine owned and registered by IntentionService itself.
 */
::class SymbolicNLPIntentionProvider public
::method init
  expose parser name
  use arg parser
  name = "SYMBOLIC_NLP"
  if parser == .nil then raise syntax 93.900 array("SymbolicNLP parser is required")
::attribute name get
::method propose
  expose parser name
  use arg service, text
  route = parser~route(text)
  intention = route~at("INTENT")
  if intention == .nil then return .Array~new
  if strip(intention) == "" then return .Array~new
  registration = service~registration(intention)
  if registration == .nil then return .Array~new
  score = 100
  if route~hasIndex("SCORE") then score = route~at("SCORE")
  proposal = .IntentionProposal~new(registration~id, score, name, .true, "SymbolicNLP route")
  if route~hasIndex("ARGUMENTS") then do
    args = route~at("ARGUMENTS")
    if args \== .nil then do
      supplier = args~supplier
      do while supplier~available
        proposal~putSlot(supplier~index, supplier~item, .true)
        supplier~next
      end
    end
  end
  return .Array~of(proposal)

/* Provider-neutral LLM bridge.
 * The supplied LLM only needs complete(prompt) -> text.  Vendor/model selection
 * is therefore outside intention resolution.
 */
::class LLMIntentionProvider public
::method provider class
  use arg llm
  return self~new(llm)

::method init
  expose llm name maxEvidenceChars
  use arg llm
  if llm == .nil then raise syntax 93.900 array("LLM provider is required")
  name = "LLM"
  maxEvidenceChars = 16000
::attribute name get
::attribute maxEvidenceChars get
::attribute maxEvidenceChars set

::method propose
  expose llm name
  use arg service, text
  prompt = self~buildPrompt(service, text)
  reply = llm~complete(prompt)
  return self~decodeReply(service, reply, name)

::method buildPrompt
  use arg service, text
  prompt = "Classify the caller's intention using only the registered intentions below." || .endOfLine
  prompt = prompt || "Return exactly one line: INTENT=<id>;SCORE=<0-100>" || .endOfLine
  prompt = prompt || "If unknown return INTENT=;SCORE=0" || .endOfLine
  registrations = service~registrations
  supplier = registrations~supplier
  do while supplier~available
    registration = supplier~item
    prompt = prompt || registration~id || " => " || registration~phrase || " [bucket=" || registration~bucketName || "]" || .endOfLine
    supplier~next
  end

  prompt = prompt || "CORPUS EVIDENCE:" || .endOfLine
  evidenceText = self~evidenceText(service)
  if evidenceText == "" then prompt = prompt || "(none)" || .endOfLine
  else prompt = prompt || evidenceText
  prompt = prompt || "INPUT=" || text
  return prompt

::method evidenceText
  expose maxEvidenceChars
  use arg service
  output = ""
  buckets = service~buckets
  bucketSupplier = buckets~supplier
  do while bucketSupplier~available
    bucket = bucketSupplier~item
    evidenceItems = bucket~evidence
    evidenceIndex = 1
    do while evidenceIndex <= evidenceItems~items
      material = evidenceItems~at(evidenceIndex)
      line = "[" || bucket~name || "] " || material~source || ": " || material~content || .endOfLine
      remaining = maxEvidenceChars - output~length
      if remaining <= 0 then return output
      if line~length > remaining then return output || line~substr(1, remaining)
      output = output || line
      evidenceIndex = evidenceIndex + 1
    end
    bucketSupplier~next
  end
  return output

::method decodeReply
  use arg service, reply, providerName
  line = strip(reply)
  intent = ""
  score = 0
  remaining = line
  do while remaining \== ""
    parse var remaining piece ';' remaining
    parse var piece key '=' fieldValue
    key = translate(strip(key))
    fieldValue = strip(fieldValue)
    if key == "INTENT" then intent = translate(fieldValue)
    if key == "SCORE" then do
      if datatype(fieldValue, "W") then score = fieldValue
    end
  end
  if intent == "" then return .Array~new
  registration = service~registration(intent)
  if registration == .nil then return .Array~new
  proposal = .IntentionProposal~new(registration~id, score, providerName, .false, "LLM classification")
  return .Array~of(proposal)

::requires "IntentionService.cls"
