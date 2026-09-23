parse source . . here
root = filespec("L", here)
store = root || "/lesson-store"
memPath = root || "/lesson-memory.journal"
address command "rm -rf" store memPath
address command "mkdir -p" store
manager = .ObjectQueueManager~new(store, .QueueGraphPayloadCodec~new, "llmpa-admin")
binding = .LlmPaQueueBinding~new(manager)
call must binding~ensureQueues, "ensure queues"
memory = .LlmPaMemoryStore~new(memPath)
worker = .LlmPaWorker~new(binding, memory, .LessonOrchestrator~new, "gemma")
submitted = binding~submit("lesson", "repair ED209 queue | The first attempt failed because the required class include path was missing; adding the module src path fixed it.")
call must submitted, "submit lesson"
call must worker~processOne, "process lesson"
reply = binding~collectReply(submitted~value["request_id"])
call must reply, "collect lesson"
call mustBool reply~value["kind"] = "LESSON", "lesson reply kind"
call mustBool reply~value["lesson"]~hasIndex("value"), "paired lesson persisted"
context = memory~context("lesson ED209 queue", 8)
call must context, "lesson recalled"
call mustBool context~value~items >= 1, "lesson available to future work"
address command "rm -rf" store memPath
say "PASS test_lessons"
exit 0

must: procedure
  use arg r,label
  if \r~ok then do; say "FAIL" label r~code r~detail; exit 1; end
return
mustBool: procedure
  use arg ok,label
  if \ok then do; say "FAIL" label; exit 1; end
return

::class LessonOrchestrator public
::method runOnce
  use arg modelName, prompt, maxTokens
  return .LlmPaResult~success(.LessonModelResult~new("LESSONS" || "0a" || "- observed include-path failure" || "0a" || "PITFALLS" || "0a" || "- do not run without REXX_PATH" || "0a" || "NEXT_TIME" || "0a" || "- run the dependency smoke check first" || "0a" || "OPEN_FOLLOWUP" || "0a" || "none"))

::class LessonModelResult public
::attribute text get
::method init
  expose text
  use arg textArg
  text = textArg

::requires "LlmPaWorker.cls"
