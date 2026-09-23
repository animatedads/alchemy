parse source . . here
root = filespec("L", here)
store = root || "/model-live-store"
memPath = root || "/model-live-memory.journal"
address command "rm -rf" store memPath
address command "mkdir -p" store
manager = .ObjectQueueManager~new(store, .QueueGraphPayloadCodec~new, "llmpa-admin")
binding = .LlmPaQueueBinding~new(manager)
call must binding~ensureQueues, "ensure"
orch = .FakeOrchestrator~new
worker = .LlmPaWorker~new(binding, .LlmPaMemoryStore~new(memPath), orch, "gemma")
submit = binding~submit("message", "hello Gemma")
call must submit, "submit message"
call must worker~processOne, "process with model"
reply = binding~collectReply(submit~value["request_id"])
call must reply, "collect"
call mustBool reply~value["status"] = "REPLIED", "model reply status"
call mustBool reply~value["text"] = "Happy to help, Codex.", "model text"
call mustBool reply~value["action_taken"] = "NONE", "no tool"
call mustBool orch~lastPrompt~pos("cheerful and helpful") > 0, "Gemma PA prompt"
address command "rm -rf" store memPath
say "PASS test_model_orchestrator"
exit 0
must: procedure
  use arg r,label
  if \r~ok then do; say "FAIL" label r~code r~detail; exit 1; end
return
mustBool: procedure
  use arg ok,label
  if \ok then do; say "FAIL" label; exit 1; end
return

::class FakeOrchestrator public
::attribute lastPrompt get
::method init
  expose lastPrompt
  lastPrompt = ""
::method runOnce
  expose lastPrompt
  use arg modelName, prompt, maxTokens
  lastPrompt = prompt
  return .LlmPaResult~success(.FakeModelResult~new("Happy to help, Codex."))

::class FakeModelResult public
::attribute text get
::attribute toolExecuted get
::attribute toolName get
::attribute toolCallId get
::method init
  expose text toolExecuted toolName toolCallId
  use arg textArg
  text = textArg
  toolExecuted = .false
  toolName = ""
  toolCallId = ""

::requires "LlmPaWorker.cls"
