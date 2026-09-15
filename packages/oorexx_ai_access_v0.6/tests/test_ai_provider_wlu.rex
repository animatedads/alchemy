packageRoot = arg(1)
if packageRoot = "" then packageRoot = "."
call main packageRoot
exit 0

main:
  procedure
  use arg packageRoot
  say "AI ACCESS V0.6 WLU START"

  verifier = .RuntimePinnedSourceVerifier~new
  kernel = .RuntimeKernel~new(verifier)
  module = stageBundle(kernel, verifier, packageRoot)
  call ok kernel~activate("prod", "ai.provider.fixture", module~generationId), "activate AI provider"

  abilityRegistry = .AbilityRegistry~new(kernel)
  loaded = .AbilityProfileLoader~readFile(packageRoot || "/fixtures/profiles/ai_provider_v1.ability"); call ok loaded, "load AI profile"
  stagedProfile = abilityRegistry~stage("prod", loaded~value); call ok stagedProfile, "stage AI profile"; profileGeneration = stagedProfile~value
  call ok abilityRegistry~activate("prod", "client-ai", profileGeneration~generationId), "activate AI profile"

  credentials = .AbilityCredentialStore~new
  call ok credentials~register("aiw1", "secret", "prod", "client-ai"), "register AI WLU credential"

  clock = .WLUTestTimeSource~new(1000000)
  keys = .WLUFastMacKeyRing~new
  ignore = keys~addKey("hot-ai", "000102030405060708090a0b0c0d0e0f")
  ledger = .WLUMemoryLedger~new
  authority = .WLUAuthority~new(keys, ledger, clock)
  account = .WLUAccount~new("acct-client-ai", 10000000)
  authority~addAccount(account)
  bucket = .WLUCapacityBucket~new("ai-provider", 3000000, 250000, clock~nowTick)
  authority~addBucket(bucket)
  authority~bindAccount("client-ai", "ABILITY:*", account~accountId)
  authority~bindBucket("client-ai", "ABILITY:*", bucket~bucketId)
  card = .WLURateCard~new("ai.tokens", "2026-08")
  card~addRule(.WLURateRule~new("AI_INPUT_TOKEN", 100000))
  card~addRule(.WLURateRule~new("AI_OUTPUT_TOKEN", 100000))
  card~seal
  authority~addRateCard(card)
  authority~bindRateCard("client-ai", "ABILITY:*", "ai.tokens", "2026-08")

  bridge = .AbilityWLUBridge~new(authority)
  planner = .DeterministicAIWLUPlanner~new
  call ok bridge~registerPlanner("model.complete", planner), "register AI WLU planner"

  router = .AbilityHttpRouter~new(abilityRegistry, credentials, .AbilityResultStore~new(300,100), bridge)
  server = .AbilityHttpServer~new(router, "127.0.0.1", 0, .AbilityHttpLimits~new(4096,16384,32,2048), 32)
  activity = server~start("serve")
  call awaitServer server
  port = server~port
  auth = "Authorization: Bearer ab1.aiw1.secret"

  response = req(port, "GET /v1/abilities HTTP/1.1", .array~of("Host: localhost", auth), "")
  call eq 200, status(response), "ability catalogue"
  catalogue = json(response)~at("abilities")~at(1)
  call yes catalogue~at("wlu_admission")~value, "AI ability advertises WLU admission"
  call eq "work.load.units/0.12", catalogue~at("wlu_api_version"), "WLU API version"

  requestBody = '{"model":"fixture-model","prompt":"one two three","max_output_tokens":4}'
  response = post(port, auth, requestBody)
  call eq 200, status(response), "WLU-managed AI completion"
  envelope = json(response)
  business = envelope~at("result")
  call eq "V1:one two three", business~at("text"), "AI business result"
  call no business~hasIndex("usage"), "business result does not contain usage accounting"
  call no business~hasIndex("execution"), "business result does not contain execution metadata"
  execution = envelope~at("execution")~at("wlu")
  call eq "ai.tokens", execution~at("rate_card_id"), "AI rate card id"
  call eq "2026-08", execution~at("rate_card_version"), "AI rate card version"
  call eq 700000, execution~at("expected_micro_wlu"), "forecast reserves input plus max output"
  call eq 500000, execution~at("actual_micro_wlu"), "actual AI token work settled"
  call eq 2, execution~at("actual_fact_count"), "actual input/output fact count"
  call eq 500000, account~spentMicroWlu, "AI actual work charged"

  requestBody = '{"model":"fixture-model","prompt":"reject-before","max_output_tokens":2}'
  response = post(port, auth, requestBody)
  call eq 422, status(response), "provider rejects before work"
  rejected = json(response)
  call eq 0, rejected~at("execution")~at("wlu")~at("actual_fact_count"), "pre-work failure has zero actual facts"
  call eq "RELEASED", rejected~at("execution")~at("wlu")~at("settlement_state"), "pre-work reservation released"
  call eq 500000, account~spentMicroWlu, "pre-work failure spends zero"

  requestBody = '{"model":"fixture-model","prompt":"reject-after","max_output_tokens":2}'
  response = post(port, auth, requestBody)
  call eq 422, status(response), "provider rejects after work"
  rejected = json(response)
  call eq 200000, rejected~at("execution")~at("wlu")~at("actual_micro_wlu"), "post-work failure retains actual usage"
  call eq "SETTLED", rejected~at("execution")~at("wlu")~at("settlement_state"), "post-work reservation settled"
  call eq 700000, account~spentMicroWlu, "post-work failure charged performed work"

  inspectionOutcome = abilityRegistry~acquire("prod", "client-ai"); call ok inspectionOutcome, "acquire provider inspection session"; inspection = inspectionOutcome~value
  providerModule = inspection~module("provider")
  beforeDenied = providerModule~runtimeInvocationCount
  hold = authority~reserve("client-ai", "ABILITY:MODEL.COMPLETE", 2300000, 30, "exhaust-ai-provider")
  call ok hold, "exhaust AI capacity bucket"
  call eq 0, bucket~tokensMicroWlu, "AI capacity bucket exhausted"

  requestBody = '{"model":"fixture-model","prompt":"denied request","max_output_tokens":2}'
  response = post(port, auth, requestBody)
  call eq 429, status(response), "capacity denial is HTTP 429"
  denied = json(response)
  call eq "WLU_CAPACITY_EXHAUSTED", denied~at("wlu_code"), "capacity denial code"
  call eq beforeDenied, providerModule~runtimeInvocationCount, "WLU denial occurs before provider execution"
  call eq 700000, account~spentMicroWlu, "denied request not charged"

  ignore = authority~release(hold~value)
  call ok inspection~release, "release inspection session"
  call ok server~stop, "stop AI WLU server"
  call awaitStopped server

  say "  spent_micro_wlu=" || account~spentMicroWlu
  say "  provider_invocations=" || beforeDenied
  say "AI ACCESS V0.6 WLU: OK"
  return

stageBundle:
  procedure
  use arg kernel, verifier, packageRoot
  builder = .RuntimeBundleBuilder~new
  alchemyRoot = value("ALCHEMY_OBJECTS_ROOT",, "ENVIRONMENT")
  if alchemyRoot = "" then do
    say "FAILED: ALCHEMY_OBJECTS_ROOT not set"
    exit 55
  end
  call ok builder~addFile(alchemyRoot || "/src/AlchemyEvidence.cls", "AlchemyEvidence.cls"), "add Alchemy evidence base"
  call ok builder~addFile(alchemyRoot || "/src/AlchemySecurity.cls", "AlchemySecurity.cls"), "add Alchemy security base"
  call ok builder~addFile(alchemyRoot || "/src/AlchemyLockedMethod.cls", "AlchemyLockedMethod.cls"), "add Alchemy locked-method base"
  call ok builder~addFile(alchemyRoot || "/src/AlchemyObject.cls", "AlchemyObject.cls"), "add Alchemy object base"
  call ok builder~addFile(packageRoot || "/src/AIProviderAccess.cls", "AIProviderAccess.cls"), "add AI provider core"
  call ok builder~addFile(packageRoot || "/fixtures/modules/DeterministicAIProvider_v1.cls", "DeterministicAIProvider.cls"), "add AI provider fixture"
  built = builder~build; call ok built, "build AI provider bundle"
  bundle = built~value
  call ok verifier~pin("ability:ai:provider:v1", bundle~sourceLines), "pin AI provider bundle"
  artifact = .RuntimeArtifact~new("ai.provider.fixture", "CAPABILITY", "1.0.0", "ability:ai:provider:v1", "DeterministicAIProviderModule", bundle~sourceLines, .AIProviderAccessBuild~API_VERSION)
  staged = kernel~stage("prod", artifact); call ok staged, "stage AI provider"
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
  if outcome == .nil then do; say "FAILED:" label "nil"; exit 61; end
  if \outcome~ok then do; say "FAILED:" label outcome~code outcome~detail; exit 61; end
  return

eq:
  use arg expected, actual, label
  if expected \== actual then do
    say "FAILED:" label
    say " expected=" expected
    say " actual=" actual
    exit 62
  end
  return

yes:
  use arg value, label
  if \value then do; say "FAILED:" label; exit 63; end
  return

no:
  use arg value, label
  if value then do; say "FAILED:" label; exit 64; end
  return

::requires "RuntimeRegistry.cls"
::requires "RuntimeBundleBuilder.cls"
::requires "AbilitySchema.cls"
::requires "AbilityRegistry.cls"
::requires "AbilityResultStore.cls"
::requires "AbilityApiDescription.cls"
::requires "AbilityHttpServer.cls"
::requires "AbilityWLU.cls"
::requires "AIProviderAccess.cls"
::requires "DeterministicAIWLUPlanner.cls"
::requires "WorkLoadUnits.cls"
::requires "json.cls"
