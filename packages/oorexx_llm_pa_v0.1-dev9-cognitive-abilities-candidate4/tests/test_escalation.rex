parse source . . here
root = filespec("L", here)
store = root || "/escalation-store"
address command "rm -rf" store
address command "mkdir -p" store
manager = .ObjectQueueManager~new(store, .QueueGraphPayloadCodec~new, "llmpa-admin")
binding = .LlmPaQueueBinding~new(manager)
call must binding~ensureQueues, "queues"
primary = .EscalationModel~new("THINKING_REQUIRED|multi-step diagnosis")
fallback = .EscalationModel~new("DEEPER ANSWER: the evidence is insufficient; inspect the recorded queue state next")
worker = .LlmPaWorker~new(binding, .LlmPaMemoryStore~new(root || "/memory"), primary, "gemma", .nil, .nil, .nil, .nil, .nil, fallback)
submitted = binding~submit("ask", "Diagnose this complex multi-step failure")
call must submitted, "submit"
call must worker~processOne, "process"
reply = binding~collectReply(submitted~value["request_id"])
call must reply, "reply"
call mustBool primary~calls = 1, "primary called"
call mustBool fallback~calls = 1, "fallback called only after marker"
call mustBool reply~value["text"]~pos("DEEPER ANSWER") > 0, "fallback answer returned"
address command "rm -rf" store
say "PASS test_escalation"
exit 0

must: procedure
  use arg answer, label
  if \answer~ok then do; say "FAIL" label answer~code answer~detail; exit 1; end
return
mustBool: procedure
  use arg ok, label
  if \ok then do; say "FAIL" label; exit 1; end
return

::class EscalationModel public
::attribute calls get
::method init
  expose text calls
  use arg textArg
  text = textArg
  calls = 0
::method runOnce
  expose text calls
  calls += 1
  return .LlmPaResult~success(.EscalationReply~new(text))

::class EscalationReply public
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
