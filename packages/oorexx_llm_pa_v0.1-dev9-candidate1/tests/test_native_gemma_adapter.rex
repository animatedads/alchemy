/* Provider/identity gate test using a fake ApiClient. No network and no curl. */
fake = .FakeOllamaApiClient~new
orch = .LlmPaOllamaOrchestrator~new("gemma2:2b", "http://127.0.0.1:11434", fake)
verified = orch~verifyModel
call must verified, "model verified"
call mustBool verified~value = "gemma2:2b", "verified exact model"

out = orch~runOnce("gemma2:2b", "Say hello", 128)
call must out, "completion"
call mustBool out~value~text = "Cheerfully live, Codex!", "live adapter content"
call mustBool out~value~model~lower~pos("gemma") > 0, "Gemma model identity"
call mustBool fake~tagsCalls = 1, "tags probe occurred"
call mustBool fake~chatCalls = 1, "chat completion occurred"

wrong = orch~runOnce("llama3", "Say hello", 128)
call mustFail wrong, "non-Gemma model rejected"
call mustBool wrong~code = "GEMMA_MODEL_MISMATCH", "wrong model code"

say "PASS test_native_gemma_adapter"
exit 0

must: procedure
  use arg r,label
  if \r~ok then do; say "FAIL" label r~code r~detail; exit 1; end
return
mustFail: procedure
  use arg r,label
  if r~ok then do; say "FAIL" label "unexpected OK"; exit 1; end
return
mustBool: procedure
  use arg ok,label
  if \ok then do; say "FAIL" label; exit 1; end
return

::class FakeOllamaApiClient public
::attribute tagsCalls get
::attribute chatCalls get
::method init
  expose tagsCalls chatCalls
  tagsCalls = 0
  chatCalls = 0
::method execute
  expose tagsCalls chatCalls
  use arg request
  if request~url~right(9) = "/api/tags" then do
    tagsCalls += 1
    body = '{"models":[{"name":"gemma2:2b"},{"name":"other:1b"}]}'
    return .ApiResponse~new(request~id, 200, .directory~new, body, 1, "", 0)
  end
  if request~url~right(20) = "/v1/chat/completions" then do
    chatCalls += 1
    body = '{"model":"gemma2:2b","choices":[{"message":{"role":"assistant","content":"Cheerfully live, Codex!"},"finish_reason":"stop"}],"usage":{"prompt_tokens":4,"completion_tokens":5}}'
    return .ApiResponse~new(request~id, 200, .directory~new, body, 2, "", 0)
  end
  return .ApiResponse~new(request~id, 404, .directory~new, "", 1, "", 0)

::requires "LlmPaNativeOllama.cls"
