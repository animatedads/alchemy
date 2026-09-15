/* Natural-language remind timing belongs to Gemma; ooRexx validates and arms. */
parse source . . here
root = filespec("L", here)
store = root || "/gemma-reminder-decision-store"
memPath = root || "/gemma-reminder-decision-memory.journal"
address command "rm -rf" store memPath
address command "mkdir -p" store

manager = .ObjectQueueManager~new(store, .QueueGraphPayloadCodec~new, "llmpa-admin")
binding = .LlmPaQueueBinding~new(manager)
call must binding~ensureQueues, "ensure queues"
memory = .LlmPaMemoryStore~new(memPath)
call must memory~remember("ED209E", "Google video worker; use GCloud tooling for recovery", "codex", "seed", .array~of("ed209e", "gcloud"), "operator"), "seed memory"
reminders = .LlmPaReminderService~new(binding)
orch = .ReminderDecisionOrchestrator~new
worker = .LlmPaWorker~new(binding, memory, orch, "gemma2:2b", reminders)

/* This is the exact style that previously fell into memory recall. Gemma now
 * interprets the typo and supplies the initial Alarm delay. */
submitted = binding~submit("remind", "10 secdonds time, what is ed209e")
call must submitted, "submit natural future reminder"
call must worker~processOne, "Gemma decides future timing"
reply = binding~collectReply(submitted~value["request_id"])
call must reply, "collect scheduled acknowledgement"
call mustBool reply~value["kind"] = "REMINDER_SCHEDULED", "future remind schedules"
call mustBool reply~value["delay_seconds"] = 10, "Gemma chose ten seconds"
call mustBool reply~value["reminder_message"] = "what is ed209e", "Gemma detached reminder text"
call mustBool reply~value["schedule_decision_model_used"] = .true, "decision came from model"
call mustBool reply~value["schedule_decision_source"] = "gemma:gemma2:2b", "decision source named"
call mustBool reminders~armedCount = 1, "exactly one one-shot alarm armed"
reminderId = reply~value["reminder_id"]
rec = reminders~record(reminderId)
call must rec, "scheduled record"
call mustBool rec~value["one_shot"] = .true, "initial alarm is one-shot"
call mustBool rec~value["decision_source"] = "gemma:gemma2:2b", "record preserves Gemma decision source"
call mustBool orch~lastDecisionPrompt~pos("Current local date/time on the PA host") > 0, "Gemma receives current host time"
call mustBool orch~lastDecisionPrompt~pos("secdonds") > 0, "exact user timing phrase supplied to Gemma"
call must reminders~cancel(reminderId), "cancel test alarm"
call mustBool reminders~armedCount = 0, "cancelled test alarm retired"

/* If Gemma initially says RECALL despite an explicit future time, ooRexx may
 * request reconsideration, but Gemma still supplies the delay. */
submitted = binding~submit("remind", "3 secdonds time remind me to inspect ED209E")
call must submitted, "submit reconsideration reminder"
call must worker~processOne, "Gemma reconsiders explicit timing"
reply = binding~collectReply(submitted~value["request_id"])
call must reply, "collect reconsidered schedule"
call mustBool reply~value["kind"] = "REMINDER_SCHEDULED", "reconsidered request schedules"
call mustBool reply~value["delay_seconds"] = 3, "Gemma supplies reconsidered delay"
call mustBool reply~value["schedule_decision_source"] = "gemma:gemma2:2b", "reconsidered decision remains Gemma-owned"
reminderId = reply~value["reminder_id"]
call must reminders~cancel(reminderId), "cancel reconsideration alarm"

/* A remind with no future intent is classified by Gemma as recall-now. */
submitted = binding~submit("remind", "what is ED209E")
call must submitted, "submit recall reminder"
call must worker~processOne, "Gemma decides recall"
reply = binding~collectReply(submitted~value["request_id"])
call must reply, "collect recall"
call mustBool reply~value["kind"] = "REMINDER", "recall remains memory operation"
call mustBool reply~value["memories"]~items >= 1, "recalled fact supplied"
call mustBool reply~value["text"]~pos("Google video worker") > 0, "recalled ED209E fact"
call mustBool reminders~armedCount = 0, "recall creates no alarm"

/* Ambiguous future intent must fail closed rather than invent a time. */
submitted = binding~submit("remind", "later remind me to inspect ED209E")
call must submitted, "submit unresolved future reminder"
call must worker~processOne, "Gemma reports unresolved timing"
reply = binding~collectReply(submitted~value["request_id"])
call must reply, "collect unresolved"
call mustBool reply~value["status"] = "FAILED", "unresolved future timing fails"
call mustBool reply~value["code"] = "REMINDER_TIME_UNRESOLVED", "unresolved code"
call mustBool reminders~armedCount = 0, "unresolved timing creates no alarm"

address command "rm -rf" store memPath
say "PASS test_gemma_reminder_decision"
exit 0

must: procedure
  use arg r,label
  if \r~ok then do; say "FAIL" label r~code r~detail; exit 1; end
return
mustBool: procedure
  use arg ok,label
  if \ok then do; say "FAIL" label; exit 1; end
return

::class ReminderDecisionOrchestrator public
::attribute lastDecisionPrompt get
::method init
  expose lastDecisionPrompt
  lastDecisionPrompt = ""
::method runOnce
  expose lastDecisionPrompt
  use arg modelName, prompt, maxTokens
  if prompt~pos("Interpret ONE natural-language REMIND request") > 0 then do
    lastDecisionPrompt = prompt
    if prompt~lower~pos("request:" || "0a"x || "10 secdonds time, what is ed209e") > 0 then return .LlmPaResult~success(.ReminderDecisionModelResult~new("SCHEDULE|10|what is ed209e"))
    if prompt~lower~pos("request:" || "0a"x || "3 secdonds time remind me to inspect ed209e") > 0 then return .LlmPaResult~success(.ReminderDecisionModelResult~new("RECALL"))
    if prompt~lower~pos("request:" || "0a"x || "later remind me") > 0 then return .LlmPaResult~success(.ReminderDecisionModelResult~new("UNRESOLVED|no concrete future time was supplied"))
    return .LlmPaResult~success(.ReminderDecisionModelResult~new("RECALL"))
  end
  if prompt~pos("previous classification was RECALL") > 0 then return .LlmPaResult~success(.ReminderDecisionModelResult~new("SCHEDULE|3|remind me to inspect ED209E"))
  return .LlmPaResult~success(.ReminderDecisionModelResult~new("Happy to help, Codex."))

::class ReminderDecisionModelResult public
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
