/* No-model qualification daemon. This launcher is intentionally deterministic.
 * Use bin/llmpad.rex for the real local Gemma deployment.
 */
parse arg storeRoot
if storeRoot = "" then storeRoot = value("LLMPA_STORE_ROOT", , "ENVIRONMENT")
if storeRoot = "" then storeRoot = "/tmp/llmpa"
token = value("LLMPA_BRIDGE_TOKEN", , "ENVIRONMENT")
if token = "" then do; say "LLMPA_BRIDGE_TOKEN is required"; exit 2; end
portText = value("LLMPA_BRIDGE_PORT", , "ENVIRONMENT")
if portText = "" then portText = 0
knowledgeRoot = value("LLMPA_KNOWLEDGE_ROOT", , "ENVIRONMENT")
if knowledgeRoot = "" then knowledgeRoot = storeRoot || "/knowledge.d"
address command "mkdir -p" storeRoot storeRoot || "/queue" knowledgeRoot
manager = .ObjectQueueManager~new(storeRoot || "/queue", .QueueGraphPayloadCodec~new, "llmpa-admin")
binding = .LlmPaQueueBinding~new(manager)
ready = binding~ensureQueues
if \ready~ok then do; say ready~code ready~detail; exit 3; end
memory = .LlmPaMemoryStore~new(storeRoot || "/memory.journal")
knowledge = .LlmPaKnowledgeStore~new(knowledgeRoot)
reminders = .LlmPaReminderService~new(binding)
worker = .LlmPaWorker~new(binding, memory, .nil, "gemma", reminders, knowledge)
access = .LlmPaCommandAccessPoint~new(binding, token, "127.0.0.1", portText)
if \access~serveAsync then do; say "LLMPA_BRIDGE_START_FAILED"; exit 4; end
say "LLMPA_BRIDGE_PORT=" || access~port
say "LLMPA_MODEL=NONE"
say "LLMPA_READY=1"
do forever
  depth = manager~depth("LLMPA.REQUEST", "gemma")
  if depth~ok then do
    if depth~value["ready"] > 0 then do
      worked = worker~processOne
      if \worked~ok then call SysSleep 0.02
      iterate
    end
  end
  call SysSleep 0.05
end
exit 0
::requires "LlmPaWorker.cls"
::requires "LlmPaReminder.cls"
::requires "LlmPaCommandBridge.cls"
::requires "LlmPaKnowledge.cls"
