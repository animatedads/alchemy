packageRoot = arg(1)
if packageRoot = "" then packageRoot = "."
call main packageRoot
exit 0

main:
  procedure
  use arg packageRoot
  say "OPENAI COMPAT WLU HTTP V0.5 START"
  secretMarker = "FAKE-OPENAI-SECRET-7E4B"
  call value "AI_OPENAI_COMPAT_ENDPOINT", "http://fixture.invalid/v1/chat/completions", "ENVIRONMENT"
  call value "AI_OPENAI_COMPAT_CREDENTIAL_REFERENCE", "provider.primary", "ENVIRONMENT"
  call value "AI_OPENAI_COMPAT_CREDENTIAL_ENV", "AI_OPENAI_COMPAT_TEST_SECRET", "ENVIRONMENT"
  call value "AI_OPENAI_COMPAT_TEST_SECRET", secretMarker, "ENVIRONMENT"
  call value "AI_OPENAI_COMPAT_MODELS", "fixture-model", "ENVIRONMENT"
  call value "AI_OPENAI_COMPAT_TIMEOUT", "5", "ENVIRONMENT"
  call value "AI_OPENAI_COMPAT_MAX_OUTPUT", "32", "ENVIRONMENT"
  call value "AI_OPENAI_COMPAT_CURL", packageRoot || "/tests/fixtures/fake_curl.sh", "ENVIRONMENT"
  call value "AI_OPENAI_COMPAT_ALLOW_HTTP_TEST", "1", "ENVIRONMENT"

  verifier = .RuntimePinnedSourceVerifier~new
  kernel = .RuntimeKernel~new(verifier)
  module = stageBundle(kernel, verifier, packageRoot)
  call ok kernel~activate("prod", "ai.provider.openai-compat", module~generationId), "activate OpenAI-compatible provider"

  abilityRegistry = .AbilityRegistry~new(kernel)
  loaded = .AbilityProfileLoader~readFile(packageRoot || "/fixtures/profiles/openai_compat.ability"); call ok loaded, "load OpenAI-compatible profile"
  stagedProfile = abilityRegistry~stage("prod", loaded~value); call ok stagedProfile, "stage OpenAI-compatible profile"; profileGeneration = stagedProfile~value
  call ok abilityRegistry~activate("prod", "client-ai", profileGeneration~generationId), "activate OpenAI-compatible profile"

  credentials = .AbilityCredentialStore~new
  call ok credentials~register("aic1", "secret", "prod", "client-ai"), "register WLU credential"

  clock = .WLUTestTimeSource~new(1000000)
  keys = .WLUFastMacKeyRing~new
  ignore = keys~addKey("hot-openai", "000102030405060708090a0b0c0d0e0f")
  ledger = .WLUMemoryLedger~new
  authority = .WLUAuthority~new(keys, ledger, clock)
  account = .WLUAccount~new("acct-client-ai", 20000000)
  authority~addAccount(account)
  bucket = .WLUCapacityBucket~new("openai-compat", 6000000, 0, clock~nowTick)
  authority~addBucket(bucket)
  authority~bindAccount("client-ai", "ABILITY:*", account~accountId)
  authority~bindBucket("client-ai", "ABILITY:*", bucket~bucketId)
  card = .WLURateCard~new("ai.tokens", "2026-08")
  card~addRule(.WLURateRule~new("AI_INPUT_TOKEN", 100000))
  card~addRule(.WLURateRule~new("AI_OUTPUT_TOKEN", 100000))
  card~seal
  authority~addRateCard(card)
  authority~bindRateCard("client-ai", "ABILITY:*", "ai.tokens", "2026-08")

  modelPolicy = .OpenAICompatModelPolicy~new(.array~of("fixture-model"), 32)
  budgetPolicy = .OpenAICompatTokenBudgetPolicy~new(1, 8, 0, 30)
  planner = .OpenAICompatWLUPlanner~new(modelPolicy, .OpenAICompatConservativeTokenEstimator~new(budgetPolicy), budgetPolicy)
  bridge = .AbilityWLUBridge~new(authority)
  call ok bridge~registerPlanner("model.complete", planner), "register OpenAI-compatible WLU planner"

  router = .AbilityHttpRouter~new(abilityRegistry, credentials, .AbilityResultStore~new(300,100), bridge)
  server = .AbilityHttpServer~new(router, "127.0.0.1", 0, .AbilityHttpLimits~new(4096,16384,32,2048), 32)
  activity = server~start("serve")
  call awaitServer server
  port = server~port
  auth = "Authorization: Bearer ab1.aic1.secret"

  requestBody = '{"model":"fixture-model","prompt":"hello provider","max_output_tokens":7}'
  response = post(port, auth, requestBody)
  call eq 200, status(response), "WLU-managed OpenAI-compatible completion"
  envelope = json(response)
  business = envelope~at("result")
  call eq "provider says hello", business~at("text"), "provider business result"
  call no business~hasIndex("usage"), "business result excludes provider usage"
  execution = envelope~at("execution")~at("wlu")
  call eq "work.load.units/0.11", execution~at("wlu_api_version"), "WLU API version"
  call eq 2900000, execution~at("expected_micro_wlu"), "conservative input plus requested output reserved"
  call eq 500000, execution~at("actual_micro_wlu"), "provider-reported actual usage settled"
  call eq 2, execution~at("actual_fact_count"), "actual input/output facts"
  call eq 500000, account~spentMicroWlu, "actual provider work charged"

  inspectionOutcome = abilityRegistry~acquire("prod", "client-ai"); call ok inspectionOutcome, "acquire provider inspection session"; inspection = inspectionOutcome~value
  providerModule = inspection~module("provider")
  beforeDenied = providerModule~runtimeInvocationCount
  call eq 1, beforeDenied, "one dynamic provider invocation after success"
  call eq 5500000, bucket~tokensMicroWlu, "unused forecast capacity refunded after settlement"
  hold = authority~reserve("client-ai", "ABILITY:MODEL.COMPLETE", 5500000, 30, "exhaust-openai-compat")
  call ok hold, "exhaust provider capacity bucket"
  call eq 0, bucket~tokensMicroWlu, "provider capacity bucket exhausted"

  response = post(port, auth, requestBody)
  call eq 429, status(response), "capacity denial is HTTP 429"
  denied = json(response)
  call eq "WLU_CAPACITY_EXHAUSTED", denied~at("wlu_code"), "capacity denial code"
  call eq beforeDenied, providerModule~runtimeInvocationCount, "WLU denial occurs before Runtime Registry provider execution"
  call eq 500000, account~spentMicroWlu, "capacity-denied request not charged"

  ignore = authority~release(hold~value)
  call ok inspection~release, "release inspection session"
  call ok server~stop, "stop OpenAI-compatible WLU server"
  call awaitStopped server
  call value "AI_OPENAI_COMPAT_TEST_SECRET", "", "ENVIRONMENT"

  evidence = .AlchemyCanonical~encode(planner~instrumentationEvents)
  call eq 0, evidence~pos("hello provider"), "planner instrumentation excludes prompt contents"
  call eq 0, evidence~pos(secretMarker), "planner instrumentation excludes secret"
  call eq 0, evidence~pos("provider.primary"), "planner instrumentation excludes credential reference"
  say "  expected_micro_wlu=2900000"
  say "  actual_micro_wlu=500000"
  say "  provider_invocations=" || beforeDenied
  say "OPENAI COMPAT WLU HTTP V0.5: OK"
  return

stageBundle:
  procedure
  use arg kernel, verifier, packageRoot
  builder = .RuntimeBundleBuilder~new
  alchemyRoot = value("ALCHEMY_OBJECTS_ROOT",, "ENVIRONMENT")
  aiAccessRoot = value("AI_ACCESS_ROOT",, "ENVIRONMENT")
  secretBrokerRoot = value("SECRET_BROKER_ROOT",, "ENVIRONMENT")
  if alchemyRoot = "" then do; say "FAILED: ALCHEMY_OBJECTS_ROOT not set"; exit 75; end
  if aiAccessRoot = "" then do; say "FAILED: AI_ACCESS_ROOT not set"; exit 75; end
  if secretBrokerRoot = "" then do; say "FAILED: SECRET_BROKER_ROOT not set"; exit 75; end
  call ok builder~addFile(alchemyRoot || "/src/AlchemyEvidence.cls", "AlchemyEvidence.cls"), "add Alchemy evidence base"
  call ok builder~addFile(alchemyRoot || "/src/AlchemySecurity.cls", "AlchemySecurity.cls"), "add Alchemy security base"
  call ok builder~addFile(alchemyRoot || "/src/AlchemyLockedMethod.cls", "AlchemyLockedMethod.cls"), "add Alchemy locked-method base"
  call ok builder~addFile(alchemyRoot || "/src/AlchemyObject.cls", "AlchemyObject.cls"), "add Alchemy object base"
  call ok builder~addFile(aiAccessRoot || "/src/AIProviderAccess.cls", "AIProviderAccess.cls"), "add AI access core"
  call ok builder~addFile(secretBrokerRoot || "/src/SecretBroker.cls", "SecretBroker.cls"), "add Secret Broker"
  call ok builder~addFile(packageRoot || "/src/OpenAICompatProvider.cls", "OpenAICompatProvider.cls"), "add OpenAI-compatible provider"
  built = builder~build; call ok built, "build OpenAI-compatible provider bundle"
  bundle = built~value
  call ok verifier~pin("ability:ai:openai-compat:v5", bundle~sourceLines), "pin OpenAI-compatible bundle"
  artifact = .RuntimeArtifact~new("ai.provider.openai-compat", "CAPABILITY", "0.5.0", "ability:ai:openai-compat:v5", "OpenAICompatRuntimeModule", bundle~sourceLines, .OpenAICompatProviderBuild~API_VERSION)
  staged = kernel~stage("prod", artifact); call ok staged, "stage OpenAI-compatible provider"
  return staged~value

post:
  procedure
  use arg port, auth, requestBody
  headers = .array~of("Host: localhost", auth, "Content-Type: application/json", "Content-Length: " || requestBody~length)
  return req(port, "POST /v1/abilities/model.complete HTTP/1.1", headers, requestBody)

awaitServer:
  procedure
  use arg server
  do i = 1 to 500 while \server~listening
    call SysSleep 0.01
  end
  call yes server~listening, "server listening"
  return

awaitStopped:
  procedure
  use arg server
  do i = 1 to 500 while server~listening
    call SysSleep 0.01
  end
  call no server~listening, "server stopped"
  return

req:
  procedure
  use arg port, line, headers, requestBody
  crlf = "0d0a"x
  text = line || crlf
  do i = 1 to headers~items
    text = text || headers~at(i) || crlf
  end
  return raw(port, text || crlf || requestBody)

raw:
  procedure
  use arg port, text
  socket = .Socket~new
  if socket~connect(.InetAddress~new("127.0.0.1", port)) < 0 then exit 90
  offset = 1
  do while offset <= text~length
    sent = socket~send(substr(text, offset))
    if sent == .nil then leave
    if sent <= 0 then leave
    offset = offset + sent
  end
  response = ""
  do forever
    chunk = socket~recv(4096)
    if chunk == .nil then leave
    if chunk == "" then leave
    response = response || chunk
  end
  socket~close
  return response

status:
  procedure
  use arg response
  p = pos("0d0a"x, response)
  if p = 0 then return -1
  return word(left(response, p - 1), 2)

body:
  procedure
  use arg response
  marker = "0d0a0d0a"x
  p = pos(marker, response)
  if p = 0 then return ""
  return substr(response, p + marker~length)

json:
  procedure
  use arg response
  return .JSON~fromJSON(body(response))

ok:
  use arg outcome, label
  if outcome == .nil then do; say "FAILED:" label "nil"; exit 76; end
  if \outcome~ok then do; say "FAILED:" label outcome~code outcome~detail; exit 76; end
  return

eq:
  use arg expected, actual, label
  if expected \== actual then do
    say "FAILED:" label
    say " expected=" expected
    say " actual=" actual
    exit 77
  end
  return

yes:
  use arg value, label
  if \value then do; say "FAILED:" label; exit 78; end
  return

no:
  use arg value, label
  if value then do; say "FAILED:" label; exit 79; end
  return

::requires "RuntimeRegistry.cls"
::requires "RuntimeBundleBuilder.cls"
::requires "AbilitySchema.cls"
::requires "AbilityRegistry.cls"
::requires "AbilityResultStore.cls"
::requires "AbilityApiDescription.cls"
::requires "AbilityHttpServer.cls"
::requires "AbilityWLU.cls"
::requires "OpenAICompatWLU.cls"
::requires "WorkLoadUnits.cls"
::requires "json.cls"
