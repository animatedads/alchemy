parse source . . here
root = filespec("L", here)
store = root || "/remind-after-store"
memPath = root || "/remind-after-memory.journal"
address command "rm -rf" store memPath
address command "mkdir -p" store

spec = .LlmPaReminderSpec~parse("IN 10 minutes check ed209 finished build")
call must spec, "parse 10 minute reminder"
call mustBool spec~value["delay_seconds"] = 600, "10 minutes -> 600 seconds"
call mustBool spec~value["message"] = "check ed209 finished build", "message detached from delay"
bad = .LlmPaReminderSpec~parse("TOMORROW check ed209")
call mustFail bad, "non-IN expression fails"

manager = .ObjectQueueManager~new(store, .QueueGraphPayloadCodec~new, "llmpa-admin")
binding = .LlmPaQueueBinding~new(manager)
call must binding~ensureQueues, "ensure queues"
memory = .LlmPaMemoryStore~new(memPath)
reminders = .LlmPaReminderService~new(binding)
orchestrator = .FakeOrchestrator~new
worker = .LlmPaWorker~new(binding, memory, orchestrator, "gemma", reminders)

submitted = binding~submit("remind_after", "IN 1 second check ed209 finished build")
call must submitted, "submit delayed reminder"
originalRequestId = submitted~value["request_id"]
call must worker~processOne, "Gemma worker arms alarm"
armedReply = binding~collectReply(originalRequestId)
call must armedReply, "collect alarm-set acknowledgement"
call mustBool armedReply~value["kind"] = "REMINDER_SCHEDULED", "scheduled reply kind"
call mustBool armedReply~value["delay_seconds"] = 1, "one-second delay"
reminderId = armedReply~value["reminder_id"]
call mustBool reminderId \= "", "reminder id returned"
call mustBool reminders~armedCount = 1, "alarm retained while armed"

/* Native ooRexx Alarm fires on another activity and queues a fresh PA request. */
call SysSleep 1.35
rec = reminders~record(reminderId)
call must rec, "reminder record after fire"
call mustBool rec~value["status"] = "FIRED", "alarm fired"
call mustBool rec~value["parent_request_id"] = originalRequestId, "parent correlation retained in alarm record"
fireRequestId = rec~value["fire_request_id"]
call mustBool fireRequestId \= "", "fresh fire request created"
depth = manager~depth("LLMPA.REQUEST", "gemma")
call must depth, "request depth after alarm"
call mustBool depth~value["ready"] = 1, "alarm re-entered Gemma through queue"

call must worker~processOne, "Gemma processes alarm prompt"
fireReply = binding~collectReply(fireRequestId)
call must fireReply, "collect eventual reminder"
call mustBool fireReply~value["kind"] = "REMINDER", "eventual reminder kind"
call mustBool fireReply~value["reminder_id"] = reminderId, "reminder id correlated"
call mustBool fireReply~value["model_used"] = .true, "Gemma model path invoked"
call mustBool fireReply~value["text"] = "Reminder, Codex: check ED209 finished build.", "Gemma reminder returned"
call mustBool fireReply~value["action_taken"] = "NONE", "alarm grants no tool authority"
call mustBool orchestrator~lastPrompt~pos("FROM ALARM YOU SET - REMIND CODEX:") > 0, "alarm prompt marker"
call mustBool orchestrator~lastPrompt~pos("check ed209 finished build") > 0, "alarm message in Gemma prompt"

address command "rm -rf" store memPath
say "PASS test_remind_after"
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

::class FakeOrchestrator public
::attribute lastPrompt get
::method init
  expose lastPrompt
  lastPrompt = ""
::method runOnce
  expose lastPrompt
  use arg modelName, prompt, maxTokens
  lastPrompt = prompt
  return .LlmPaResult~success(.FakeModelResult~new("Reminder, Codex: check ED209 finished build."))

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
::requires "LlmPaReminder.cls"
