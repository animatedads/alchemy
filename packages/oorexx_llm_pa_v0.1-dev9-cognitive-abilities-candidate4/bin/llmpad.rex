/* Production local PA daemon: Queue Fabric + real local Gemma through
 * ooRexx AI Access / API Client. There is deliberately no deterministic
 * model fallback in this launcher. Startup fails unless the configured Gemma
 * is visible in Ollama's /api/tags response.
 */
parse source . . scriptHere
scriptDir = filespec("L", scriptHere)
packageRoot = scriptDir
if packageRoot~right(4) = "bin/" then packageRoot = packageRoot~left(packageRoot~length - 4)
parse arg storeRoot
if storeRoot = "" then storeRoot = value("LLMPA_STORE_ROOT", , "ENVIRONMENT")
if storeRoot = "" then storeRoot = "/tmp/llmpa"
token = value("LLMPA_BRIDGE_TOKEN", , "ENVIRONMENT")
if token = "" then do; say "LLMPA_BRIDGE_TOKEN is required"; exit 2; end
portText = value("LLMPA_BRIDGE_PORT", , "ENVIRONMENT")
if portText = "" then portText = 0
model = value("LLMPA_MODEL", , "ENVIRONMENT")
if model = "" then model = value("LLMPA_GEMMA_MODEL", , "ENVIRONMENT")
if model = "" then model = "gemma2:2b"
backend = value("LLMPA_MODEL_BACKEND", , "ENVIRONMENT")~string~strip~lower
if backend = "" then backend = "ollama"
baseUrl = value("LLMPA_OLLAMA_BASE_URL", , "ENVIRONMENT")
if baseUrl = "" then baseUrl = "http://127.0.0.1:11434"

knowledgeRoot = value("LLMPA_KNOWLEDGE_ROOT", , "ENVIRONMENT")
if knowledgeRoot = "" then knowledgeRoot = storeRoot || "/knowledge.d"
gopherRoot = value("LLMPA_GOPHER_ROOT", , "ENVIRONMENT")
if gopherRoot = "" then gopherRoot = packageRoot || "/deps/llm_gopher_v0.21-dev1"
gopherSphereRoot = value("LLMPA_GOPHER_SPHERE_ROOT", , "ENVIRONMENT")
if gopherSphereRoot = "" then gopherSphereRoot = packageRoot || "/deps/gopher_spheres"
gopherEnv = value("LLMPA_GOPHER_ENV", , "ENVIRONMENT")
if gopherEnv = "" then gopherEnv = storeRoot || "/gopher"
gopherCatalog = value("LLMPA_GOPHER_CATALOG", , "ENVIRONMENT")
if gopherCatalog = "" then gopherCatalog = packageRoot || "/deps/gopher_catalog.tsv"
continuityPath = value("LLMPA_CONTINUITY_PATH", , "ENVIRONMENT")
if continuityPath = "" then continuityPath = storeRoot || "/continuity.brief"
planPath = value("LLMPA_PLAN_PATH", , "ENVIRONMENT")
if planPath = "" then planPath = storeRoot || "/plans.journal"
cognitiveJournal = value("LLMPA_COGNITIVE_JOURNAL", , "ENVIRONMENT")
if cognitiveJournal = "" then cognitiveJournal = storeRoot || "/cognitive.journal.jsonl"
cognitiveScope = value("LLMPA_COGNITIVE_SCOPE", , "ENVIRONMENT")
if cognitiveScope = "" then cognitiveScope = "project:llmpa"
address command "mkdir -p" storeRoot storeRoot || "/queue" knowledgeRoot gopherEnv
manager = .ObjectQueueManager~new(storeRoot || "/queue", .QueueGraphPayloadCodec~new, "llmpa-admin")
binding = .LlmPaQueueBinding~new(manager)
ready = binding~ensureQueues
if \ready~ok then do; say ready~code ready~detail; exit 3; end
memory = .LlmPaMemoryStore~new(storeRoot || "/memory.journal")
knowledge = .LlmPaKnowledgeStore~new(knowledgeRoot)
reminders = .LlmPaReminderService~new(binding)
gopherTool = .LlmPaGopherTool~new(gopherRoot, gopherSphereRoot, gopherEnv, gopherCatalog)
gopherReady = gopherTool~probe
if \gopherReady~ok then do
  say "LLMPA_GOPHER_VERIFY_FAILED=" || gopherReady~code
  if gopherReady~detail \= "" then say "LLMPA_GOPHER_VERIFY_DETAIL=" || gopherReady~detail
  exit 6
end

routeEndpoint = value("LLMPA_ROUTE_ENDPOINT",, "ENVIRONMENT")
routeCredentialEnv = value("LLMPA_ROUTE_CREDENTIAL_ENV",, "ENVIRONMENT")
select
  when backend = "openai" then do
    if routeEndpoint = "" then routeEndpoint = value("LLMPA_OPENAI_ENDPOINT",, "ENVIRONMENT")
    if routeCredentialEnv = "" then routeCredentialEnv = value("LLMPA_OPENAI_CREDENTIAL_ENV",, "ENVIRONMENT")
    orchestrator = .LlmPaOpenAIOrchestrator~new(model, routeEndpoint, routeCredentialEnv)
  end
  when backend = "ollama" then orchestrator = .LlmPaOllamaOrchestrator~new(model, baseUrl)
  otherwise do
    say "LLMPA_MODEL_BACKEND_UNSUPPORTED=" || backend
    exit 5
  end
end
verified = orchestrator~verifyModel
if \verified~ok then do
  say "LLMPA_GEMMA_VERIFY_FAILED=" || verified~code
  if verified~detail \= "" then say "LLMPA_GEMMA_VERIFY_DETAIL=" || verified~detail
  exit 5
end
continuity = .LlmPaContinuityBrief~new(continuityPath)
plans = .LlmPaPlanManager~new(.LlmPaPlanStore~new(planPath))
packageStage = .LlmPaPackageStage~new(storeRoot || "/staging")
releaseSourceRoot = value("LLMPA_RELEASE_SOURCE_ROOT", , "ENVIRONMENT")
if releaseSourceRoot = "" then releaseSourceRoot = packageRoot
packageRelease = .LlmPaPackageRelease~new(storeRoot || "/releases", .nil, .nil, .nil, releaseSourceRoot)
cognitiveRuntime = .LlmPaCognitiveRuntime~new(cognitiveJournal, cognitiveScope)
abilityDir = value("LLMPA_ABILITY_DIR", , "ENVIRONMENT")
if abilityDir = "" then abilityDir = packageRoot || "/abilities.d"
abilityContext = .LlmPaAbilityContext~new
ignore = abilityContext~setService("plans", plans)
ignore = abilityContext~setService("continuity", continuity)
ignore = abilityContext~setService("package_stage", packageStage)
ignore = abilityContext~setService("package_release", packageRelease)
ignore = abilityContext~setService("cognitive_runtime", cognitiveRuntime)
ignore = abilityContext~setService("cognitive_service", cognitiveRuntime~service)
ignore = abilityContext~setService("cognitive_adapter", cognitiveRuntime~adapter)
ignore = abilityContext~setConfig("cognitive_scope", cognitiveScope)
abilityRegistry = .LlmPaAbilityRegistry~new(abilityDir, abilityContext)
abilityReady = abilityRegistry~load
if \abilityReady~ok then do
  say "LLMPA_ABILITY_REGISTRY_FAILED=" || abilityReady~code
  if abilityReady~detail \= "" then say "LLMPA_ABILITY_REGISTRY_DETAIL=" || abilityReady~detail
  exit 7
end
ignore = abilityContext~setService("ability_registry", abilityRegistry)
worker = .LlmPaWorker~new(binding, memory, orchestrator, model, reminders, knowledge, gopherTool, continuity, plans, .nil, .nil, packageStage, packageRelease, abilityRegistry)
lastContinuityRefresh = 0

access = .LlmPaCommandAccessPoint~new(binding, token, "127.0.0.1", portText)
if \access~serveAsync then do; say "LLMPA_BRIDGE_START_FAILED"; exit 4; end
say "LLMPA_BRIDGE_PORT=" || access~port
say "LLMPA_MODEL=" || model
say "LLMPA_MODEL_VERIFIED=1"
say "LLMPA_GOPHER=llm_gopher_v0.21-dev1"
say "LLMPA_GOPHER_READY=1"
say "LLMPA_ABILITY_COUNT=" || abilityReady~value["count"]
say "LLMPA_ABILITY_DIR=" || abilityDir
say "LLMPA_COGNITIVE_CONTINUITY=oorexx.cognitive.continuity/0.1"
say "LLMPA_COGNITIVE_SCOPE=" || cognitiveScope
say "LLMPA_COGNITIVE_STATE_COMPACTABLE=0"
say "LLMPA_READY=1"

do forever
  depth = manager~depth("LLMPA.REQUEST", "gemma")
  if depth~ok then do
    if depth~value["ready"] > 0 then do
      worked = worker~processOne
      if \worked~ok then do
        /* A failed work item is completed as a PA failure reply where possible;
         * keep the daemon alive for later independent requests. */
        call SysSleep 0.02
      end
      iterate
    end
    else do
      /* Refresh only the legacy human-readable projection cache during idle time.
       * Durable Cognitive Continuity state is independent of this cache and is
       * never compacted to fit an inference context. */
      nowMicros = .LlmPaClock~absoluteMicroseconds
      if nowMicros - lastContinuityRefresh >= (900 * 1000000) then do
        ignore = worker~refreshContinuity
        lastContinuityRefresh = nowMicros
      end
    end
  end
  call SysSleep 0.05
end
exit 0

::requires "LlmPaNativeOllama.cls"
::requires "LlmPaOpenAIOrchestrator.cls"
::requires "LlmPaWorker.cls"
::requires "LlmPaReminder.cls"
::requires "LlmPaCommandBridge.cls"
::requires "LlmPaKnowledge.cls"
::requires "LlmPaGopher.cls"
::requires "LlmPaContinuity.cls"
::requires "LlmPaPackageStage.cls"
::requires "LlmPaPackageRelease.cls"
::requires "LlmPaAbility.cls"
::requires "LlmPaCognitiveRuntime.cls"
