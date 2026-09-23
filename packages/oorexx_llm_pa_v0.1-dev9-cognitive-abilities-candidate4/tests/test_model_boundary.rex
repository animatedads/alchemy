parse source . . here
root = filespec("L", here)
store = root || "/model-boundary-store"
memPath = root || "/model-boundary-memory.journal"
address command "rm -rf" store memPath
address command "mkdir -p" store
manager = .ObjectQueueManager~new(store, .QueueGraphPayloadCodec~new, "llmpa-admin")
binding = .LlmPaQueueBinding~new(manager)
call must binding~ensureQueues, "ensure"
submit = binding~submit("message", "please inspect ED209E")
call must submit, "submit message"
worker = .LlmPaWorker~new(binding, .LlmPaMemoryStore~new(memPath))
call must worker~processOne, "process without model"
reply = binding~collectReply(submit~value["request_id"])
call must reply, "collect"
call mustBool reply~value["status"] = "FAILED", "failed closed"
call mustBool reply~value["code"] = "MODEL_NOT_CONFIGURED", "model authority absent"
call mustBool reply~value["action_taken"] = "NONE", "no action without orchestrator"
address command "rm -rf" store memPath
say "PASS test_model_boundary"
exit 0
must: procedure
  use arg r,label
  if \r~ok then do; say "FAIL" label r~code r~detail; exit 1; end
return
mustBool: procedure
  use arg ok,label
  if \ok then do; say "FAIL" label; exit 1; end
return
::requires "LlmPaWorker.cls"
