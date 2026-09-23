/* Regression: Ollama ChatCompletionRequest.stream must be a JSON boolean,
 * never the Rexx logical/numeric 0 produced by serialising .false directly. */
fake = .StrictOllamaApiClient~new
orch = .LlmPaOllamaOrchestrator~new("gemma2:2b", "http://127.0.0.1:11434", fake)
verified = orch~verifyModel
call must verified, "model verified"
out = orch~runOnce("gemma2:2b", "Return the word READY.", 64)
call must out, "completion"
call mustBool fake~sawChat = 1, "chat request observed"
call mustBool fake~streamWasBooleanFalse = 1, "stream serialized as JSON false"
say "PASS test_ollama_json_boolean"
exit 0

must: procedure
  use arg r,label
  if \r~ok then do; say "FAIL" label r~code r~detail; exit 1; end
return
mustBool: procedure
  use arg ok,label
  if \ok then do; say "FAIL" label; exit 1; end
return

::class StrictOllamaApiClient public
::attribute sawChat get
::attribute streamWasBooleanFalse get
::method init
  expose sawChat streamWasBooleanFalse
  sawChat = 0
  streamWasBooleanFalse = 0
::method execute
  expose sawChat streamWasBooleanFalse
  use arg request
  if request~url~right(9) = "/api/tags" then do
    body = '{"models":[{"name":"gemma2:2b"}]}'
    return .ApiResponse~new(request~id, 200, .directory~new, body, 1, "", 0)
  end
  if request~url~right(20) = "/v1/chat/completions" then do
    sawChat = 1
    raw = request~body~string
    /* Mimic Ollama's strict Go decoder: numeric 0 is not a boolean. */
    if raw~pos('"stream":false') = 0 | raw~pos('"stream":0') > 0 then do
      err = '{"error":"json: cannot unmarshal number into Go struct field ChatCompletionRequest.stream of type bool"}'
      return .ApiResponse~new(request~id, 400, .directory~new, err, 1, "", 0)
    end
    parsed = .JSON~fromJSON(raw)
    streamValue = parsed~at("stream")
    if streamValue \== .nil then if streamValue~isa(.JsonBoolean) then if \streamValue~value then streamWasBooleanFalse = 1
    body = '{"model":"gemma2:2b","choices":[{"message":{"role":"assistant","content":"READY"},"finish_reason":"stop"}],"usage":{"prompt_tokens":4,"completion_tokens":1}}'
    return .ApiResponse~new(request~id, 200, .directory~new, body, 2, "", 0)
  end
  return .ApiResponse~new(request~id, 404, .directory~new, "", 1, "", 0)

::requires "LlmPaNativeOllama.cls"
