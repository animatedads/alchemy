/* Target-host qualification. Requires local Ollama with the configured Gemma. */
parse source . . here
root = filespec("L", here) || "/live-gemma-store-" || time("S") || "-" || random(1000,9999)
address command "rm -rf" root
address command "mkdir -p" root
model = value("LLMPA_GEMMA_MODEL", , "ENVIRONMENT")
if model = "" then model = "gemma2:2b"
orch = .LlmPaOllamaOrchestrator~new(model)
verified = orch~verifyModel
call must verified, "live Gemma model verification"
nonce = "LLMPA-LIVE-" || random(100000,999999)
manager = .ObjectQueueManager~new(root || "/queue", .QueueGraphPayloadCodec~new, "llmpa-admin")
binding = .LlmPaQueueBinding~new(manager)
call must binding~ensureQueues, "queues"
memory = .LlmPaMemoryStore~new(root || "/memory.journal")
knowledgeRoot = root || "/knowledge.d"
address command "mkdir -p" knowledgeRoot
knowledgePath = knowledgeRoot || "/sshnode.help"
call lineout knowledgePath, "Approved local SSH helper for this qualification: ./sshnode.sh NODE"
call lineout knowledgePath, "Do not invent raw ssh syntax when this local helper applies."
call lineout knowledgePath
knowledge = .LlmPaKnowledgeStore~new(knowledgeRoot)
reminders = .LlmPaReminderService~new(binding)
packageRoot = directory()
gopher = .LlmPaGopherTool~new(packageRoot || "/deps/llm_gopher_v0.21-dev1", packageRoot || "/deps/gopher_spheres", root || "/gopher", packageRoot || "/deps/gopher_catalog.tsv")
call must gopher~probe, "live Gopher probe"
worker = .LlmPaWorker~new(binding, memory, orch, model, reminders, knowledge, gopher)

remember = binding~submit("remember", "for ssh we have a configured script ./sshnode.sh", "")
call must remember, "submit live indexed memory"
call must worker~processOne, "worker live remember"
rememberReply = binding~collectReply(remember~value["request_id"])
call must rememberReply, "collect live remember"
call mustBool rememberReply~value["memory_index_model_used"] = .true, "live Gemma authored memory index"
call mustBool hasLookup(rememberReply~value["lookup_keys"], "sshnode"), "live Gemma indexed sshnode"

sshAsk = binding~submit("ask", "What is the SSH command or helper I should use? Answer using remembered operator facts.")
call must sshAsk, "submit live memory question"
call must worker~processOne, "worker live memory question"
sshReply = binding~collectReply(sshAsk~value["request_id"])
call must sshReply, "collect live memory question"
call mustBool sshReply~value["text"]~lower~pos("sshnode") > 0, "live Gemma used indexed remembered fact"

/* Real Gemma receives project-grounded Gopher evidence when memory/local docs do not cover the question. */
gopherAsk = binding~submit("ask", "According to LLM Gopher, what owns Queue Fabric queue mutation authority?")
call must gopherAsk, "submit live Gopher question"
call must worker~processOne, "worker live Gopher question"
gopherReply = binding~collectReply(gopherAsk~value["request_id"])
call must gopherReply, "collect live Gopher question"
call mustBool gopherReply~value["model_used"] = .true, "live Gopher question used Gemma"
call mustBool gopherReply~value["gopher_used"] = .true, "live Gopher evidence used"
call mustBool gopherReply~value["gopher_sphere"] = "queue-fabric", "live Gopher selected queue-fabric"
call mustBool gopherReply~value["gopher_article_id"] = "queue-fabric.queue-authority", "live Gopher selected authority article"

/* Real Gemma determines the initial future delay for natural-language remind. */
remindText = "3 secdonds time, remind me to mention " || nonce
scheduled = binding~submit("remind", remindText)
call must scheduled, "submit live natural reminder"
call must worker~processOne, "worker live reminder decision"
scheduledReply = binding~collectReply(scheduled~value["request_id"])
call must scheduledReply, "collect live reminder decision"
call mustBool scheduledReply~value["kind"] = "REMINDER_SCHEDULED", "live Gemma scheduled initial alarm"
call mustBool scheduledReply~value["delay_seconds"] = 3, "live Gemma interpreted three seconds"
call mustBool scheduledReply~value["schedule_decision_model_used"] = .true, "live scheduling decision model flag"
call must reminders~cancel(scheduledReply~value["reminder_id"]), "retire live qualification alarm"

submit = binding~submit("ask", "Gemma, be helpful and include this exact token somewhere in your reply: " || nonce)
call must submit, "submit"
call must worker~processOne, "worker"
reply = binding~collectReply(submit~value["request_id"])
call must reply, "collect"
call mustBool reply~value["status"] = "REPLIED", "live reply"
call mustBool reply~value["model_used"] = .true, "model used flag"
call mustBool reply~value["model_name"]~caselessEquals(model), "configured model recorded"
call mustBool reply~value["text"]~pos(nonce) > 0, "nonce returned by live Gemma"
say "LIVE_GEMMA_MODEL=" || model
say "LIVE_GEMMA_REPLY=" || reply~value["text"]
address command "rm -rf" root
say "PASS test_live_gemma"
exit 0
hasLookup: procedure
  use arg keys, wanted
  do key over keys
    lower = key~string~lower
    if lower = wanted~lower then return .true
    if lower~pos(wanted~lower) > 0 then return .true
  end
  return .false

must: procedure
  use arg r,label
  if \r~ok then do; say "FAIL" label r~code r~detail; exit 1; end
return
mustBool: procedure
  use arg ok,label
  if \ok then do; say "FAIL" label; exit 1; end
return
::requires "LlmPaNativeOllama.cls"
::requires "LlmPaWorker.cls"
::requires "LlmPaReminder.cls"
::requires "LlmPaKnowledge.cls"
::requires "LlmPaGopher.cls"
