/* Live autonomous Development Floor HelloWorld worker.
 * The model receives only the bounded coding prompts from DFAutonomousCodingWorker.
 * Development Manager/WLU own admission; deterministic ooRexx execution owns acceptance.
 */
parse arg providerKind modelId instructionPath workspaceRoot runRoot
providerKind = providerKind~strip~upper
modelId = modelId~strip
if providerKind = "" then providerKind = "LLAMA"
if modelId = "" then modelId = "local-model"
if instructionPath = "" then instructionPath = "instructions/hello_world.txt"
if workspaceRoot = "" then workspaceRoot = "state/live-worker/workspace"
if runRoot = "" then runRoot = "state/live-worker/run"

address command "mkdir -p --" shellQuote(runRoot) shellQuote(workspaceRoot)
if rc <> 0 then do
  say "FAIL unable to create worker run directories"
  exit 2
end

keyHex = value("DF_WORKER_WLU_KEY",, "ENVIRONMENT")~strip
if keyHex = "" then do
  say "FAIL DF_WORKER_WLU_KEY not supplied by run_worker.sh"
  exit 2
end

keyRing = .WLUFastMacKeyRing~new
ignore = keyRing~addKey("df-live", keyHex)
wluLedger = .WLUAuthenticatedFileLedger~new(runRoot || "/wlu.auth.ledger", keyRing)
clock = .WLUTimeSource~new
authority = .WLUAuthority~new(keyRing, wluLedger, clock)
account = .WLUAccount~new("development-floor-live", 20000000)
ignore = authority~addAccount(account)
ignore = authority~bindAccount("*", "*", account~accountId)

accounting = .DFAccountingLedger~new(runRoot || "/development-floor.accounting")
control = .DFWLUControl~new(authority, accounting)
manager = .DFDevelopmentManager~new
ignore = manager~loadRegistrations("config/default_registrations.json")
ignore = manager~bindWorkControl(control)

assignmentId = "HELLO-LIVE"
assignment = .DFAssignment~new(assignmentId, "DEVFLOOR", "HELLO", "ooRexx", "write a HelloWorld application")
ignore = assignment~assignTo("hello-specialist")
ignore = manager~addAssignment(assignment)
if providerKind = "AZURE" then executionProvider = "azure-gpt-6-luna"
else executionProvider = "local-qwen-llamacpp"
ignore = manager~bindAssignmentExecution(assignment~id, "coding-specialist", executionProvider)

reserved = manager~reserveAssignmentWork(assignment~id, 2200000, 3000000, 60, 600, "hello-live")
if \reserved~ok then do
  say "FAIL WLU reservation" reserved~code reserved~detail
  exit 3
end
admitted = manager~admitAssignmentWork(assignment~id)
if \admitted~ok then do
  say "FAIL WLU admission" admitted~code admitted~detail
  exit 3
end

if providerKind = "LLAMA" then do
  config = .LlamaCppProviderConfig~fromEnvironment
  curlExecutable = value("LLAMA_CPP_CURL",, "ENVIRONMENT")~strip
  if curlExecutable = "" then curlExecutable = "curl"
  transport = .OpenAICompatCurlTransport~new(curlExecutable, .true, "NONE", "")
  provider = .OpenAICompatProviderAdapter~new(config, .nil, transport)
end
else if providerKind = "AZURE" then do
  config = .DFAzureResponsesProviderConfig~fromEnvironment
  keyEnvName = value("AZURE_OPENAI_API_KEY_ENV",, "ENVIRONMENT")~strip
  if keyEnvName = "" then keyEnvName = "AZURE_OPENAI_API_KEY"
  secretMap = .directory~new
  secretMap[config~credentialReference] = keyEnvName
  secretProvider = .MappedEnvironmentSecretProvider~new(secretMap)
  broker = .SecretBroker~new(secretProvider)
  curlExecutable = value("AZURE_OPENAI_CURL",, "ENVIRONMENT")~strip
  if curlExecutable = "" then curlExecutable = "curl"
  transport = .OpenAICompatCurlTransport~new(curlExecutable, .false, "API_KEY", "api-key")
  provider = .DFAzureResponsesProviderAdapter~new(config, broker, transport)
end
else do
  say "FAIL unsupported provider" providerKind
  exit 2
end

worker = .DFAutonomousCodingWorker~new(manager, provider)
outcome = worker~runHelloWorld(assignment~id, instructionPath, workspaceRoot, modelId, "HELLO WORLD", 512, 1000000, 100000, 1000000, 100000)

say "provider=" || providerKind
say "model=" || modelId
say "assignment=" || assignment~id
say "outcome=" || outcome~code
say "second_bite=" || outcome~secondBiteAction
say "final_stdout=" || outcome~finalStdout
say "file=" || outcome~filePath
say "sha256=" || outcome~sourceSha256
say "input_tokens=" || outcome~inputTokens
say "output_tokens=" || outcome~outputTokens
say "wlu_spent=" || outcome~consumedMicroWlu
say "run_root=" || runRoot
if outcome~ok then do
  say "PASS autonomous Development Floor live HelloWorld"
  exit 0
end
say "FAIL autonomous Development Floor live HelloWorld detail=" || outcome~detail
exit 1

shellQuote: procedure
  use arg valueArg
  text = valueArg~string
  text = text~changestr("'", "'\\''")
  return "'" || text || "'"

::requires "AutonomousCodingWorker.cls"
::requires "AzureResponsesProvider.cls"
::requires "OpenAICompatProvider.cls"
::requires "SecretBroker.cls"
::requires "WLULedger.cls"
