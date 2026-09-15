parse arg root wluRoot
if root = "" then root = "."
if wluRoot = "" then do
  say "FAILED: WLU root required"
  exit 2
end
call main root, wluRoot
exit 0

main:
  procedure
  use arg root, wluRoot
  say "ABILITY HTTP WLU V0.1 START"

  verifier = .RuntimePinnedSourceVerifier~new
  kernel = .RuntimeKernel~new(verifier)
  module = stage(kernel, verifier, root || "/fixtures/modules/HttpWLU_v1.cls", "http.wlu", "CAPABILITY", "http:wlu:1", "HttpWLUCapability")
  call ok kernel~activate("prod", "http.wlu", module~generationId), "activate WLU fixture"

  abilityRegistry = .AbilityRegistry~new(kernel)
  profile = wluProfile(module~artifactId)
  stagedProfile = abilityRegistry~stage("prod", profile)
  call ok stagedProfile, "stage WLU profile"
  generation = stagedProfile~value
  call ok abilityRegistry~activate("prod", "client-wlu", generation~generationId), "activate WLU profile"

  credentials = .AbilityCredentialStore~new
  call ok credentials~register("w1", "secret", "prod", "client-wlu"), "register WLU credential"

  clock = .WLUTestTimeSource~new(1000000)
  keys = .WLUFastMacKeyRing~new
  ignore = keys~addKey("hot-2026-08", "000102030405060708090a0b0c0d0e0f")
  ledger = .WLUMemoryLedger~new
  authority = .WLUAuthority~new(keys, ledger, clock)
  account = .WLUAccount~new("acct-client-wlu", 10000000)
  authority~addAccount(account)
  bucket = .WLUCapacityBucket~new("ability-provider", 2000000, 250000, clock~nowTick)
  authority~addBucket(bucket)
  authority~bindAccount("client-wlu", "ABILITY:*", account~accountId)
  authority~bindBucket("client-wlu", "ABILITY:*", bucket~bucketId)
  card = .WLURateCard~new("ability.tokens", "2026-08")
  card~addRule(.WLURateRule~new("TOKEN", 100000))
  card~seal
  authority~addRateCard(card)
  authority~bindRateCard("client-wlu", "ABILITY:*", "ability.tokens", "2026-08")

  bridge = .AbilityWLUBridge~new(authority)
  planner = .HttpWLUPlanner~new
  call ok bridge~registerPlanner("query", planner), "register query planner"
  call ok bridge~registerPlanner("reject.before", planner), "register pre-work rejection planner"
  call ok bridge~registerPlanner("reject.after", planner), "register post-work rejection planner"

  store = .AbilityResultStore~new(300, 100)
  router = .AbilityHttpRouter~new(abilityRegistry, credentials, store, bridge)
  server = .AbilityHttpServer~new(router, "127.0.0.1", 0, .AbilityHttpLimits~new(2048,8192,32,1024), 32)
  activity = server~start("serve")
  call awaitServer server
  port = server~port
  authHeader = "Authorization: Bearer ab1.w1.secret"

  response = req(port, "GET /v1/abilities HTTP/1.1", .array~of("Host: localhost", authHeader), "")
  call eq 200, status(response), "ability catalogue"
  abilities = json(response)~at("abilities")
  queryAbility = findAbility(abilities, "query")
  call yes queryAbility~at("wlu_admission")~value, "query advertises WLU admission"
  call eq "work.load.units/0.12", queryAbility~at("wlu_api_version"), "WLU API version"

  response = req(port, "GET /v1/openapi.json HTTP/1.1", .array~of("Host: localhost", authHeader), "")
  call eq 200, status(response), "OpenAPI"
  openapi = json(response)
  call yes openapi~at("paths")~at("/v1/queries")~at("post")~at("responses")~hasIndex("429"), "OpenAPI 429 admission response"
  openapiText = body(response)~lower
  call no openapiText~pos("balance") > 0, "OpenAPI exposes no live balance"
  call no openapiText~pos("tariff") > 0, "OpenAPI exposes no live tariff"

  requestBody = '{"actual_tokens":3}'
  headers = .array~of("Host: localhost", authHeader, "Content-Type: application/json", "Content-Length: " || requestBody~length)
  response = req(port, "POST /v1/queries HTTP/1.1", headers, requestBody)
  call eq 201, status(response), "successful WLU query"
  created = json(response)
  queryId = created~at("id")
  business = created~at("result")
  call yes business~at("wlu_managed")~value, "capability receives metering surface"
  call no business~hasIndex("wlu"), "business result has no WLU column"
  call no business~hasIndex("execution"), "business result has no execution column"
  execution = created~at("execution")~at("wlu")
  call eq "ability.tokens", execution~at("rate_card_id"), "rate card id"
  call eq "2026-08", execution~at("rate_card_version"), "rate card generation"
  call eq 400000, execution~at("expected_micro_wlu"), "forecast WLU"
  call eq 500000, execution~at("ceiling_micro_wlu"), "reservation ceiling"
  call eq 300000, execution~at("actual_micro_wlu"), "actual WLU"
  call eq 1, execution~at("actual_fact_count"), "actual fact count"
  call eq "SIPHASH-2-4-128", execution~at("proof_algorithm"), "reservation proof algorithm"
  call eq 300000, account~spentMicroWlu, "successful work charged actual only"

  response = req(port, "GET /v1/queries/" || queryId || " HTTP/1.1", .array~of("Host: localhost", authHeader), "")
  call eq 200, status(response), "materialized WLU query retrieval"
  fetched = json(response)
  call eq 300000, fetched~at("execution")~at("wlu")~at("actual_micro_wlu"), "materialized execution metadata retained"
  call no fetched~at("result")~hasIndex("wlu"), "retrieved business result remains clean"

  requestBody = '{}'
  headers = .array~of("Host: localhost", authHeader, "Content-Type: application/json", "Content-Length: " || requestBody~length)
  response = req(port, "POST /v1/abilities/reject.before HTTP/1.1", headers, requestBody)
  call eq 422, status(response), "provider rejection before work"
  rejectedBefore = json(response)
  call eq 0, rejectedBefore~at("execution")~at("wlu")~at("actual_fact_count"), "pre-work rejection has zero facts"
  call eq "RELEASED", rejectedBefore~at("execution")~at("wlu")~at("settlement_state"), "pre-work reservation released"
  call eq 300000, account~spentMicroWlu, "pre-work rejection spends zero"

  response = req(port, "POST /v1/abilities/reject.after HTTP/1.1", headers, requestBody)
  call eq 422, status(response), "provider rejection after work"
  rejectedAfter = json(response)
  call eq 200000, rejectedAfter~at("execution")~at("wlu")~at("actual_micro_wlu"), "post-work rejection actual"
  call eq "SETTLED", rejectedAfter~at("execution")~at("wlu")~at("settlement_state"), "post-work rejection settled"
  call eq 500000, account~spentMicroWlu, "post-work rejection charged"

  call ok server~stop, "stop normal WLU server"
  call awaitStopped server

  failingStore = .AlwaysFailResultStore~new(300, 100)
  failingRouter = .AbilityHttpRouter~new(abilityRegistry, credentials, failingStore, bridge)
  failingServer = .AbilityHttpServer~new(failingRouter, "127.0.0.1", 0, .AbilityHttpLimits~new(2048,8192,32,1024), 32)
  failingActivity = failingServer~start("serve")
  call awaitServer failingServer
  failingPort = failingServer~port
  requestBody = '{"actual_tokens":2}'
  headers = .array~of("Host: localhost", authHeader, "Content-Type: application/json", "Content-Length: " || requestBody~length)
  response = req(failingPort, "POST /v1/queries HTTP/1.1", headers, requestBody)
  call eq 503, status(response), "result-store failure after performed work"
  storeFailure = json(response)
  call eq 200000, storeFailure~at("execution")~at("wlu")~at("actual_micro_wlu"), "store failure retains execution evidence"
  call eq 700000, account~spentMicroWlu, "store failure does not refund performed work"
  call ok failingServer~stop, "stop failing WLU server"
  call awaitStopped failingServer

  fixtureSessionOutcome = abilityRegistry~acquire("prod", "client-wlu")
  call ok fixtureSessionOutcome, "acquire fixture inspection session"
  fixtureSession = fixtureSessionOutcome~value
  fixture = fixtureSession~module("wlu")
  call yes fixture \== .nil, "resolve WLU fixture instance"
  beforeDenied = fixture~invocationCount
  hold = authority~reserve("client-wlu", "ABILITY:QUERY", 1300000, 30, "exhaust-provider")
  call ok hold, "exhaust shared provider bucket"
  call eq 0, bucket~tokensMicroWlu, "provider bucket exhausted"

  deniedRouter = .AbilityHttpRouter~new(abilityRegistry, credentials, store, bridge)
  deniedServer = .AbilityHttpServer~new(deniedRouter, "127.0.0.1", 0, .AbilityHttpLimits~new(2048,8192,32,1024), 32)
  deniedActivity = deniedServer~start("serve")
  call awaitServer deniedServer
  deniedPort = deniedServer~port
  requestBody = '{"actual_tokens":3}'
  headers = .array~of("Host: localhost", authHeader, "Content-Type: application/json", "Content-Length: " || requestBody~length)
  response = req(deniedPort, "POST /v1/queries HTTP/1.1", headers, requestBody)
  call eq 429, status(response), "capacity denial is HTTP 429"
  denial = json(response)
  call eq "WLU_CAPACITY_EXHAUSTED", denial~at("wlu_code"), "capacity denial code"
  call eq 2, denial~at("retry_after_seconds"), "capacity retry body"
  call eq "2", header(response, "Retry-After"), "capacity Retry-After header"
  call eq beforeDenied, fixture~invocationCount, "429 occurs before dynamic side effects"
  call eq 700000, account~spentMicroWlu, "denied work not charged"
  call ok fixtureSession~release, "release fixture inspection session"
  ignore = authority~release(hold~value)
  call ok deniedServer~stop, "stop denied WLU server"
  call awaitStopped deniedServer

  say "  port=" || port
  say "  spent_micro_wlu=" || account~spentMicroWlu
  say "  retry_after=2"
  say "ABILITY HTTP WLU V0.1: OK"
  return

wluProfile:
  procedure
  use arg artifactId
  bindings = .array~of(.AbilityRuntimeBinding~new("wlu", "http.wlu", artifactId))
  abilities = .array~of(.AbilityDescriptor~new("query", "QUERY", .array~of("wlu"), .true, "WLU query"), -
                        .AbilityDescriptor~new("reject.before", "CUSTOM", .array~of("wlu"), .true, "reject before work"), -
                        .AbilityDescriptor~new("reject.after", "CUSTOM", .array~of("wlu"), .true, "reject after work"))
  return .AbilityProfileRevision~new("wlu-http", "1", "client-wlu", bindings, abilities, .array~new, .array~new, "WLU HTTP profile")

stage:
  procedure
  use arg kernel, verifier, path, id, kind, artifactId, entry
  sourceOutcome = .RuntimeSourceLoader~readFile(path)
  call ok sourceOutcome, "read WLU fixture"
  call ok verifier~pin(artifactId, sourceOutcome~value), "pin WLU fixture"
  artifact = .RuntimeArtifact~new(id, kind, "1.0.0", artifactId, entry, sourceOutcome~value)
  stageOutcome = kernel~stage("prod", artifact)
  call ok stageOutcome, "stage WLU fixture"
  return stageOutcome~value

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

findAbility:
  procedure
  use arg items, abilityId
  do i = 1 to items~items
    if items~at(i)~at("id") = abilityId then return items~at(i)
  end
  say "FAILED: ability missing" abilityId
  exit 97

header:
  procedure
  use arg response, name
  crlf = "0d0a"x
  marker = "0d0a0d0a"x
  p = pos(marker, response)
  if p = 0 then return ""
  headerText = left(response, p - 1)
  target = name~lower
  start = 1
  do forever
    ending = pos(crlf, headerText, start)
    if ending = 0 then line = substr(headerText, start)
    else line = substr(headerText, start, ending - start)
    colon = pos(":", line)
    if colon > 1 then do
      currentName = left(line, colon - 1)~strip~lower
      if currentName = target then return substr(line, colon + 1)~strip
    end
    if ending = 0 then leave
    start = ending + crlf~length
  end
  return ""

ok:
  procedure
  use arg outcome, label
  if \outcome~ok then do
    say "FAILED:" label outcome~code outcome~detail
    exit 91
  end
  return

eq:
  procedure
  use arg expected, actual, label
  if expected \== actual then do
    say "FAILED:" label "expected=" expected "actual=" actual
    exit 92
  end
  return

yes:
  procedure
  use arg value, label
  if \value then do
    say "FAILED:" label
    exit 93
  end
  return

no:
  procedure
  use arg value, label
  if value then do
    say "FAILED:" label
    exit 94
  end
  return

::class HttpWLUPlanner public
::method plan
  use arg session, descriptor, requestBody
  facts = .array~of(.AbilityMeterFact~new("TOKEN", 4, "forecast"))
  scope = "ABILITY:" || descriptor~abilityId~upper
  return .AbilityWLUPlan~new(scope, facts, 500000, 0, 30, "")

::class AlwaysFailResultStore subclass AbilityResultStore
::method create
  use arg kind, session, abilityId, rawValue, ttlSeconds = .nil, executionMetadata = .nil
  return .RuntimeResult~failure("RESULT_STORE_FIXTURE_FAILURE", "intentional materialisation failure")

::requires "AbilityWLU.cls"
::requires "AbilityHttpServer.cls"
