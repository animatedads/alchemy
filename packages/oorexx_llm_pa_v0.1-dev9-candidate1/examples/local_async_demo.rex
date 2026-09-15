/* Single-process demonstration only. Production injects the long-lived Queue
 * Fabric manager owned by the service and transports requests normally. */
parse arg root
if root = "" then root = "/tmp/llmpa-demo"
address command "rm -rf" root
address command "mkdir -p" root
manager = .ObjectQueueManager~new(root || "/queue", .QueueGraphPayloadCodec~new, "llmpa-admin")
binding = .LlmPaQueueBinding~new(manager)
ready = binding~ensureQueues
if \ready~ok then do; say ready~code ready~detail; exit 1; end
memory = .LlmPaMemoryStore~new(root || "/memory.journal")
reminders = .LlmPaReminderService~new(binding)
worker = .LlmPaWorker~new(binding, memory, .nil, "gemma", reminders)

submit = binding~submit("remember", "ED209E", "Google Server, have to restart it with gcloud")
say "submitted async request" submit~value["request_id"]
say "request queue depth before Gemma:" manager~depth("LLMPA.REQUEST", "codex")~value["ready"]
ignore = worker~processOne
reply = binding~collectReply(submit~value["request_id"])
say "Gemma reply:" reply~value["text"]

later = binding~submit("remind_after", "IN 1 second check ed209 finished build")
say "submitted delayed reminder" later~value["request_id"]
ignore = worker~processOne
armed = binding~collectReply(later~value["request_id"])
say "Gemma reply:" armed~value["text"]
call SysSleep 1.25
say "queue depth after Alarm:" manager~depth("LLMPA.REQUEST", "gemma")~value["ready"]
ignore = worker~processOne
fired = binding~collectReply
say "eventual reminder:" fired~value["text"]
exit 0
::requires "LlmPaWorker.cls"
::requires "LlmPaReminder.cls"
