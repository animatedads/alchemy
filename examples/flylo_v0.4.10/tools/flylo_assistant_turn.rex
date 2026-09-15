/* One structured assistant turn behind ./flylo.
 * Input/output are JSON. Grok provides schema-constrained language
 * interpretation and a structured reply plan. FlyLo alone decides and
 * executes engine lookups.
 *
 * Internal conditions are stage-labelled for server diagnostics.  Raw
 * condition text is never returned to the passenger/browser.
 */
stage = "BOOT"
frame = .nil
work = .nil
signal on syntax name failed

stage = "REQUEST_PARSE"
line = linein()
if line = "" then do; call emitFailure "FLYLO_ASSISTANT_REQUEST_EMPTY", "assistant request was empty"; exit 2; end
request = .JSON~fromJSON(line)
if \request~isa(.Directory) then do; call emitFailure "FLYLO_ASSISTANT_REQUEST_INVALID", "assistant request must be a JSON object"; exit 2; end

stage = "REQUEST_FIELDS"
question = field(request, "question", "")
conversationEvidence = field(request, "conversationEvidence", "")
referenceDate = field(request, "referenceDate", "")
turnId = field(request, "turnId", "TURN")
currentFrame = request["currentFrame"]
browserContext = request["browserContext"]
if browserContext == .nil then browserContext = .directory~new
frame = .FlyLoLanguageFrame~fromDirectory(currentFrame)

stage = "ASSISTANT_INIT"
assistant = .FlyLoGrokAssistant~fromEnvironment

stage = "INTERPRET_PROVIDER"
interpretReply = assistant~interpretStructured(question, frame~asDirectory, referenceDate, conversationEvidence)
if \interpretReply~ok then do
  call emitProviderFailure interpretReply
  exit 3
end

stage = "INTERPRET_PARSE"
interpretation = parseObject(interpretReply~text, "FLYLO_INTERPRETATION_JSON_INVALID")
if interpretation == .nil then exit 3

stage = "FRAME_MERGE"
merge = frame~applyInterpretation(interpretation, referenceDate)
if \merge~ok then do; call emitFailure merge~code, merge~detail; exit 3; end

stage = "ENGINE_INIT"
runtime = .FlyLoBackendFactory~fixture
journeyOps = .FlyLoAssistantJourneyAdapter~new(runtime)
bookingOps = .FlyLoAssistantBookingAdapter~new(runtime)
travelInfo = .FlyLoTravelInformationAuthority~new
orchestrator = .FlyLoAssistantOrchestrator~new(journeyOps, bookingOps, travelInfo)

stage = "ORCHESTRATE"
work = orchestrator~evaluate(frame)
evidence = work["evidence"]
missing = work["missing"]

stage = "RESPONSE_PROVIDER"
responseReply = assistant~planStructuredResponse(question, frame~asDirectory, work, conversationEvidence, browserContext)
if \responseReply~ok then do
  call emitProviderFailure responseReply
  exit 3
end

stage = "RESPONSE_PARSE"
plan = parseObject(responseReply~text, "FLYLO_RESPONSE_PLAN_JSON_INVALID")
if plan == .nil then exit 3

stage = "UTTERANCE_BUILD"
structured = .FlyLoStructuredReplyFactory~build(turnId, plan, frame, work["evidenceSource"], responseReply~model)
if \structured~ok then do; call emitFailure structured~code, structured~detail; exit 3; end
summary = structured~value

stage = "OUTPUT_BUILD"
out = .directory~new
out["ok"] = .JSON~true
out["code"] = "OK"
out["text"] = summary["text"]
out["model"] = responseReply~model
out["finishReason"] = responseReply~finishReason
out["frame"] = frame~asDirectory
out["missing"] = missing
out["structuredUtterance"] = summary
out["authorityEvidence"] = evidence

operation = work["operation"]~string
if operation = "SEARCH" then do
  action = .directory~new
  action["type"] = "FLIGHT_SEARCH_RESULT"
  action["offer"] = evidence["journey"]
  out["action"] = action
end
else if operation~pos("BOOKING_SERVICE_PRECHECK") > 0 then do
  action = .directory~new
  action["type"] = "BOOKING_SERVICE_REQUIRED"
  action["service"] = frame~serviceRequest
  action["missing"] = missing
  action["product"] = evidence["checkedBagProduct"]
  out["action"] = action
end
else if operation~pos("BOOKING_LOOKUP") > 0 then do
  action = .directory~new
  action["type"] = "BOOKING_LOOKUP_RESULT"
  action["service"] = frame~serviceRequest
  action["lookup"] = evidence["bookingLookup"]
  action["product"] = evidence["checkedBagProduct"]
  out["action"] = action
end
say .JSON~toJSON(out)
exit 0

failed:
  signal off syntax
  c = condition("O")
  diagnosticCode = "UNKNOWN"
  diagnosticPosition = 0
  if c \== .nil then if c~isa(.Directory) then do
    if c["CODE"] \== .nil then diagnosticCode = c["CODE"]~string
    if c["POSITION"] \== .nil then diagnosticPosition = c["POSITION"]~string
  end
  call emitInternalFailure stage, diagnosticCode, diagnosticPosition, frame
  exit 4

field: procedure
  use arg d, key, defaultValue
  v = d[key]
  if v == .nil then return defaultValue
  return v~string

parseObject: procedure
  use arg text, errorCode
  signal on syntax name invalidJson
  value = .JSON~fromJSON(strip(text~string))
  signal off syntax
  if value == .nil | \value~isa(.Directory) then do; call emitFailure errorCode, "structured model output was not a JSON object"; return .nil; end
  return value
invalidJson:
  signal off syntax
  call emitFailure errorCode, "structured model output was not valid JSON"
  return .nil

emitProviderFailure: procedure
  use arg reply
  call emitFailure reply~code, reply~detail
  return

emitInternalFailure: procedure
  use arg stageArg, conditionCode, positionArg, frameArg
  d = .directory~new
  d["ok"] = .JSON~false
  d["code"] = "FLYLO_ASSISTANT_INTERNAL_" || stageArg~string
  d["detail"] = "The FlyLo assistant hit an internal structured-runtime condition."
  diagnostic = .directory~new
  diagnostic["stage"] = stageArg~string
  diagnostic["conditionCode"] = conditionCode~string
  diagnostic["position"] = positionArg
  d["diagnostic"] = diagnostic
  if frameArg \== .nil then if frameArg~isa(.FlyLoLanguageFrame) then d["partialFrame"] = frameArg~asDirectory
  say .JSON~toJSON(d)
  return

emitFailure: procedure
  use arg code, detail
  d = .directory~new
  d["ok"] = .JSON~false
  d["code"] = code
  d["detail"] = detail
  d["text"] = ""
  say .JSON~toJSON(d)
  return

::requires "FlyLoGrokAssistant.cls"
::requires "FlyLoAssistantOrchestrator.cls"
::requires "json.cls"
