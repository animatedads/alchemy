/* One-shot stdin/stdout bridge used only behind ./flylo.
   Input and output are JSON. Provider credentials remain in the environment. */
signal on syntax name failed
line = linein()
if line = "" then do
  call emitFailure "FLYLO_ASSISTANT_REQUEST_EMPTY", "assistant request was empty"
  exit 2
end
request = .JSON~fromJSON(line)
if \request~isa(.Directory) then do
  call emitFailure "FLYLO_ASSISTANT_REQUEST_INVALID", "assistant request must be a JSON object"
  exit 2
end
question = request["question"]
if question == .nil then question = ""
operationalEvidence = request["operationalEvidence"]
if operationalEvidence == .nil then operationalEvidence = "BROWSER SESSION CONTEXT: unavailable"
legalEvidence = request["legalEvidence"]
if legalEvidence == .nil then legalEvidence = "LEGAL EFFECT STATUS=NOT_EVALUATED"
conversationEvidence = request["conversationEvidence"]
if conversationEvidence == .nil then conversationEvidence = ""

assistant = .FlyLoGrokAssistant~fromEnvironment
reply = assistant~assist(question, operationalEvidence, legalEvidence, conversationEvidence)
responseData = .directory~new
responseData["ok"] = reply~ok
responseData["code"] = reply~code
responseData["detail"] = reply~detail
responseData["text"] = reply~text
responseData["model"] = reply~model
responseData["finishReason"] = reply~finishReason
say .JSON~toJSON(responseData)
if reply~ok then exit 0
exit 3

failed:
  signal off syntax
  call emitFailure "FLYLO_ASSISTANT_INTERNAL", "assistant runtime failed safely"
  exit 4

emitFailure:
  use arg code, detail
  d = .directory~new
  d["ok"] = .false
  d["code"] = code
  d["detail"] = detail
  d["text"] = ""
  say .JSON~toJSON(d)
  return

::requires "FlyLoGrokAssistant.cls"
::requires "json.cls"
