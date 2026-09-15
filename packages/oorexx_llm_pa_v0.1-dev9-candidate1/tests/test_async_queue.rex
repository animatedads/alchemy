parse source . . here
root = filespec("L", here)
store = root || "/queue-store"
memPath = root || "/queue-memory.journal"
address command "rm -rf" store memPath
address command "mkdir -p" store
manager = .ObjectQueueManager~new(store, .QueueGraphPayloadCodec~new, "llmpa-admin")
binding = .LlmPaQueueBinding~new(manager)
r = binding~ensureQueues
call must r~ok, "ensure queues"
submit = binding~submit("remember", "ED209E", "Google Server, have to restart it with gcloud")
call must submit~ok, "async submit"
requestId = submit~value["request_id"]
/* submit returns before worker processing: this is the async contract */
call must manager~depth("LLMPA.REQUEST", "codex")~value["ready"] = 1, "request queued"
memory = .LlmPaMemoryStore~new(memPath)
worker = .LlmPaWorker~new(binding, memory)
worked = worker~processOne
call must worked~ok, "worker process remember"
call must manager~depth("LLMPA.REQUEST", "gemma")~value["ready"] = 0, "request acked"
call must manager~depth("LLMPA.REPLY", "codex")~value["ready"] = 1, "reply queued"
reply = binding~collectReply(requestId)
call must reply~ok, "collect correlated reply"
call must reply~value["status"] = "REPLIED", "reply status"
call must reply~value["request_id"] = requestId, "correlation retained"
submit2 = binding~submit("remind", "ED209E")
call must submit2~ok, "submit remind"
worked = worker~processOne
call must worked~ok, "worker remind"
reply2 = binding~collectReply(submit2~value["request_id"])
call must reply2~ok, "collect reminder"
call must reply2~value["memories"]~items = 1, "one remembered fact"
address command "rm -rf" store memPath
say "PASS test_async_queue"
exit 0
must: procedure
  use arg ok, label
  if \ok then do
    say "FAIL" label
    exit 1
  end
return
::requires "LlmPaWorker.cls"
