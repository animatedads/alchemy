parse source . . here
root = filespec("L", here)
store = root || "/recovery-store"
memPath = root || "/recovery-memory.journal"
address command "rm -rf" store memPath
address command "mkdir -p" store
manager1 = .ObjectQueueManager~new(store, .QueueGraphPayloadCodec~new, "llmpa-admin")
binding1 = .LlmPaQueueBinding~new(manager1)
call must binding1~ensureQueues~ok, "ensure queues manager1"
submit = binding1~submit("remember", "GCloud", "should use our tool")
call must submit~ok, "submit durable request"
requestId = submit~value["request_id"]
manager1 = .nil
binding1 = .nil
/* Re-open the Queue Fabric store: queued PA work must still be there. */
manager2 = .ObjectQueueManager~new(store, .QueueGraphPayloadCodec~new, "llmpa-admin")
binding2 = .LlmPaQueueBinding~new(manager2)
call must binding2~ensureQueues~ok, "ensure queues manager2"
call must manager2~depth("LLMPA.REQUEST", "gemma")~value["ready"] = 1, "durable request recovered"
worker = .LlmPaWorker~new(binding2, .LlmPaMemoryStore~new(memPath))
call must worker~processOne~ok, "process recovered request"
reply = binding2~collectReply(requestId)
call must reply~ok, "collect recovered request reply"
call must reply~value["request_id"] = requestId, "recovered correlation"
address command "rm -rf" store memPath
say "PASS test_queue_recovery"
exit 0
must: procedure
  use arg ok, label
  if \ok then do
    say "FAIL" label
    exit 1
  end
return
::requires "LlmPaWorker.cls"
