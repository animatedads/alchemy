/* Luna-only Development Floor staged project runner.
 * Azure discovery/key handling is performed by run_project.sh.
 * Luna plans, Luna implements, deterministic ooRexx evidence runs, Luna reviews.
 */
parse arg modelId specPath workspaceRoot runRoot
modelId = modelId~strip
if modelId = "" then modelId = "gpt-6-luna"
if specPath = "" then specPath = "spec/hello_world_project.json"
if workspaceRoot = "" then workspaceRoot = "state/live-project/workspace"
if runRoot = "" then runRoot = "state/live-project/run"

address command "mkdir -p --" shellQuote(runRoot) shellQuote(workspaceRoot)
if rc <> 0 then do
  say "FAIL unable to create project run directories"
  exit 2
end

keyHex = value("DF_WORKER_WLU_KEY",, "ENVIRONMENT")~strip
if keyHex = "" then do
  say "FAIL DF_WORKER_WLU_KEY not supplied by run_project.sh"
  exit 2
end

keyRing = .WLUFastMacKeyRing~new
ignore = keyRing~addKey("df-project", keyHex)
wluLedger = .WLUAuthenticatedFileLedger~new(runRoot || "/wlu.auth.ledger", keyRing)
clock = .WLUTimeSource~new
authority = .WLUAuthority~new(keyRing, wluLedger, clock)
account = .WLUAccount~new("development-floor-project", 30000000)
ignore = authority~addAccount(account)
ignore = authority~bindAccount("*", "*", account~accountId)

accounting = .DFAccountingLedger~new(runRoot || "/development-floor.accounting")
control = .DFWLUControl~new(authority, accounting)
manager = .DFDevelopmentManager~new
ignore = manager~loadRegistrations("config/default_registrations.json")
ignore = manager~bindWorkControl(control)

config = .DFAzureResponsesProviderConfig~fromEnvironment
keyEnvName = value("AZURE_OPENAI_API_KEY_ENV",, "ENVIRONMENT")~strip
if keyEnvName = "" then keyEnvName = "AZURE_OPENAI_API_KEY"
secretMap = .Directory~new
secretMap[config~credentialReference] = keyEnvName
secretProvider = .MappedEnvironmentSecretProvider~new(secretMap)
broker = .SecretBroker~new(secretProvider)
curlExecutable = value("AZURE_OPENAI_CURL",, "ENVIRONMENT")~strip
if curlExecutable = "" then curlExecutable = "curl"
transport = .OpenAICompatCurlTransport~new(curlExecutable, .false, "API_KEY", "api-key")
journal = .DFRunJournal~new(runRoot)
provider = .DFAzureResponsesProviderAdapter~new(config, broker, transport, journal)

managementModel = value("DF_REASONING_MANAGER_MODEL",, "ENVIRONMENT")~strip
if managementModel = "" then managementModel = "qwen2.5-1.5b-npu"
managementConfig = .LlamaCppProviderConfig~fromEnvironment
managementCurl = value("LLAMA_CPP_CURL",, "ENVIRONMENT")~strip
if managementCurl = "" then managementCurl = "curl"
managementTransport = .OpenAICompatCurlTransport~new(managementCurl, .true, "NONE", "")
managementProvider = .OpenAICompatProviderAdapter~new(managementConfig, .nil, managementTransport)
reasoningThreshold = decimalEnv("DF_REASONING_ALIGNMENT_THRESHOLD", 0.70)

ignore = journal~event("SESSION", "START", "model=" || modelId || " spec=" || specPath)
session = .DFLunaPlanningSession~new(manager, provider, journal, managementProvider, managementModel, reasoningThreshold)
planTokens = positiveWholeEnv("DF_PROJECT_PLAN_MAX_OUTPUT", 20000)
implementTokens = positiveWholeEnv("DF_PROJECT_IMPLEMENT_MAX_OUTPUT", 20000)
reviewTokens = positiveWholeEnv("DF_PROJECT_REVIEW_MAX_OUTPUT", 20000)
managementTokens = positiveWholeEnv("DF_REASONING_MANAGER_MAX_OUTPUT", 512)
ignore = journal~event("SESSION", "TOKEN_BUDGETS", "plan=" || planTokens || " implement=" || implementTokens || " review=" || reviewTokens || " management=" || managementTokens)
outcome = session~runHelloProject(specPath, workspaceRoot, modelId, planTokens, implementTokens, reviewTokens, managementTokens)

say "provider=AZURE_LUNA"
say "model=" || modelId
say "project=" || outcome~projectId
say "outcome=" || outcome~code
say "review=" || outcome~reviewDecision
say "reasoning_score=" || outcome~reasoningScore
say "reasoning_verdict=" || outcome~reasoningVerdict
say "plan=" || outcome~planPath
say "artifact=" || outcome~artifactPath
say "sha256=" || outcome~artifactSha
say "input_tokens=" || outcome~inputTokens
say "output_tokens=" || outcome~outputTokens
say "wlu_spent=" || outcome~consumedMicroWlu
say "run_root=" || runRoot
summary = "provider=AZURE_LUNA" || "0a"x || -
          "model=" || modelId || "0a"x || -
          "project=" || outcome~projectId || "0a"x || -
          "outcome=" || outcome~code || "0a"x || -
          "review=" || outcome~reviewDecision || "0a"x || -
          "reasoning_score=" || outcome~reasoningScore || "0a"x || -
          "reasoning_verdict=" || outcome~reasoningVerdict || "0a"x || -
          "plan=" || outcome~planPath || "0a"x || -
          "artifact=" || outcome~artifactPath || "0a"x || -
          "sha256=" || outcome~artifactSha || "0a"x || -
          "input_tokens=" || outcome~inputTokens || "0a"x || -
          "output_tokens=" || outcome~outputTokens || "0a"x || -
          "wlu_spent=" || outcome~consumedMicroWlu || "0a"x || -
          "run_root=" || runRoot || "0a"x
ignore = journal~persist("SESSION", "SUMMARY", "session/summary.txt", summary, outcome~code)
if outcome~ok then do
  ignore = journal~event("SESSION", "COMPLETE", "PASS")
  say "PASS Luna planned and executed Development Floor project"
  exit 0
end
ignore = journal~event("SESSION", "COMPLETE", "FAIL " || outcome~code, "", "", .Log~ERROR)
say "FAIL Luna planned Development Floor project detail=" || outcome~detail
exit 1

decimalEnv: procedure
  use arg envName, defaultValue
  raw = value(envName,, "ENVIRONMENT")~strip
  if raw = "" then return defaultValue
  if \datatype(raw, "N") then return defaultValue
  if raw < 0 then return defaultValue
  if raw > 1 then return defaultValue
  return raw

positiveWholeEnv: procedure
  use arg envName, defaultValue
  raw = value(envName,, "ENVIRONMENT")~strip
  if raw = "" then return defaultValue
  if \datatype(raw, "W") then return defaultValue
  if raw < 1 then return defaultValue
  return raw

shellQuote: procedure
  use arg valueArg
  text = valueArg~string
  text = text~changestr("'", "'\\''")
  return "'" || text || "'"

::requires "PlanningSession.cls"
::requires "RunJournal.cls"
::requires "AzureResponsesProvider.cls"
::requires "OpenAICompatProvider.cls"
::requires "SecretBroker.cls"
::requires "WLULedger.cls"
