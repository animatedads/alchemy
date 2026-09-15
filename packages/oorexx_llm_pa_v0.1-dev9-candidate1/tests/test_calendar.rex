parse source . . here
root = filespec("L", here)
store = root || "/calendar-store"
memPath = root || "/calendar-memory.journal"
address command "rm -rf" store memPath
address command "mkdir -p" store

manager = .ObjectQueueManager~new(store, .QueueGraphPayloadCodec~new, "llmpa-admin")
binding = .LlmPaQueueBinding~new(manager)
call must binding~ensureQueues, "ensure queues"
memory = .LlmPaMemoryStore~new(memPath)
reminders = .LlmPaReminderService~new(binding)
calendarTool = .LlmPaReadCalendarTool~new(reminders)
call mustBool calendarTool~name = "read_calendar", "calendar tool name"
call mustBool calendarTool~accessMode = "READ_ONLY", "calendar tool is read-only"
call mustBool calendarTool~eventable == .true, "calendar tool is eventable"
call mustBool calendarTool~mutating == .false, "calendar tool cannot mutate"
orchestrator = .CalendarFakeOrchestrator~new
worker = .LlmPaWorker~new(binding, memory, orchestrator, "gemma", reminders)

scheduled = reminders~schedule("IN 1 second check ED209E", "parent-calendar-test")
call must scheduled, "schedule"
reminderId = scheduled~value["reminder_id"]
calendar = reminders~calendar
call must calendar, "calendar read"
call mustBool calendar~value~items = 1, "one armed item"
entry = calendar~value[1]
call mustBool entry["reminder_id"] = reminderId, "calendar reminder id"
call mustBool entry["message"] = "check ED209E", "calendar message"
call mustBool entry["status"] = "ARMED", "calendar status"
call mustBool entry["one_shot"] == .true, "calendar marks one-shot"
call mustBool entry["remaining_seconds"] >= 0 & entry["remaining_seconds"] <= 1, "remaining seconds bounded"

submitted = binding~submit("calendar")
call must submitted, "submit calendar command"
call must worker~processOne, "worker calendar command"
reply = binding~collectReply(submitted~value["request_id"])
call must reply, "collect calendar reply"
call mustBool reply~value["kind"] = "CALENDAR", "calendar reply kind"
call mustBool reply~value["calendar"]~items = 1, "calendar reply contains item"
call mustBool reply~value["text"]~pos("check ED209E") > 0, "calendar text contains event"

asked = binding~submit("message", "What reminders are currently armed?")
call must asked, "submit natural calendar question"
call must worker~processOne, "worker natural calendar question"
askedReply = binding~collectReply(asked~value["request_id"])
call must askedReply, "collect natural answer"
call mustBool orchestrator~lastPrompt~pos("Authoritative armed one-shot calendar") > 0, "Gemma receives authoritative calendar"
call mustBool orchestrator~lastPrompt~pos("check ED209E") > 0, "Gemma sees armed reminder"
call mustBool orchestrator~lastPrompt~pos("No Alarm repeats automatically") > 0, "one-shot calendar doctrine in prompt"

/* The native Alarm is one-shot. Once fired it vanishes from future calendar;
 * no replacement Alarm is created implicitly. */
call SysSleep 1.35
rec = reminders~record(reminderId)
call must rec, "fired record exists"
call mustBool rec~value["status"] = "FIRED", "alarm fired once"
calendar = reminders~calendar
call must calendar, "calendar after fire"
call mustBool calendar~value~items = 0, "fired alarm removed from future calendar"
call mustBool reminders~armedCount = 0, "no implicit repeat alarm"

/* Consume the fresh alarm_fire request so the fake Gemma path is also clean. */
call must worker~processOne, "process fired one-shot alarm"
fireReply = binding~collectReply(rec~value["fire_request_id"])
call must fireReply, "collect fired alarm reply"
call mustBool orchestrator~lastPrompt~pos("This Alarm is one-shot") > 0, "alarm prompt explains one-shot"
call mustBool orchestrator~lastPrompt~pos("explicitly set a new one-shot Alarm") > 0, "re-arm requires fresh decision"

address command "rm -rf" store memPath
say "PASS test_calendar"
exit 0

must: procedure
  use arg r,label
  if \r~ok then do; say "FAIL" label r~code r~detail; exit 1; end
return
mustBool: procedure
  use arg ok,label
  if \ok then do; say "FAIL" label; exit 1; end
return

::class CalendarFakeOrchestrator public
::attribute lastPrompt get
::method init
  expose lastPrompt
  lastPrompt = ""
::method runOnce
  expose lastPrompt
  use arg modelName, prompt, maxTokens
  lastPrompt = prompt
  return .LlmPaResult~success(.CalendarFakeModelResult~new("Calendar checked."))

::class CalendarFakeModelResult public
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

::requires "LlmPaTools.cls"
