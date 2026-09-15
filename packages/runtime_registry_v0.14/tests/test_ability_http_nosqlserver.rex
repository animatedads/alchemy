parse arg registryRoot nosqlRoot
if registryRoot = "" then registryRoot = "."
if nosqlRoot = "" then do
  say "ABILITY HTTP NOSQLSERVER: SKIP (no NoSQLServer root)"
  exit 0
end
call main registryRoot, nosqlRoot
exit 0

main:
  procedure
  use arg registryRoot, nosqlRoot
  nosqlVersion = detectNoSQLVersion(nosqlRoot)
  say "ABILITY HTTP NOSQLSERVER V" || nosqlVersion || " START"
  call assertTrue stream(nosqlRoot || "/src/NoSQLServer.cls", "c", "query exists") <> "", "NoSQLServer source exists"
  call assertTrue stream(nosqlRoot || "/tests/TestSupport.cls", "c", "query exists") <> "", "NoSQLServer TestSupport exists"

  verifier = .RuntimePinnedSourceVerifier~new
  kernel = .RuntimeKernel~new(verifier)
  abilityRegistry = .AbilityRegistry~new(kernel)
  staged = stageNoSQL(kernel, verifier, registryRoot, nosqlRoot)
  call mustOk kernel~activate("prod", "nosql.data", staged~generationId), "activate NoSQL data ability"

  runtimeBindings = .array~of(.AbilityRuntimeBinding~new("data", "nosql.data", staged~artifactId))
  abilities = .array~of(.AbilityDescriptor~new("query", "QUERY", .array~of("data"), .true, "Query configured federated resources"))
  dataBindings = .array~new
  dataBindings~append(.AbilityDataBinding~new("orders", "data", "table:orders", "READ"))
  dataBindings~append(.AbilityDataBinding~new("customers", "data", "table:customers_snapshot", "READ"))
  joinSql = "SELECT o.id AS order_id,c.name AS customer_name,o.total AS total FROM orders o INNER JOIN customers_snapshot c ON o.customer_id=c.id ORDER BY o.id"
  dataBindings~append(.AbilityDataBinding~new("customer-orders", "data", "sql:" || joinSql, "READ"))
  profile = .AbilityProfileRevision~new("federated-bot", "1", "client-nosql", runtimeBindings, abilities, dataBindings, .array~new, "NoSQL federated data profile")
  profileStage = abilityRegistry~stage("prod", profile); call mustOk profileStage, "stage NoSQL profile"
  profileGeneration = profileStage~value
  call mustOk abilityRegistry~activate("prod", "client-nosql", profileGeneration~generationId), "activate NoSQL profile"

  credentials = .AbilityCredentialStore~new
  call mustOk credentials~register("nosql-key", "nosql-secret", "prod", "client-nosql"), "register NoSQL HTTP key"
  resultStore = .AbilityResultStore~new(300, 100)
  router = .AbilityHttpRouter~new(abilityRegistry, credentials, resultStore)
  server = .AbilityHttpServer~new(router, "127.0.0.1", 0, .AbilityHttpLimits~new(4096, 16384, 48, 65536), 32)
  serverActivity = server~start("serve")
  do waitHttp = 1 to 500 while \server~listening
    call SysSleep 0.01
  end
  call assertTrue server~listening, "NoSQL HTTP server listening"
  port = server~port
  authHeader = "Authorization: Bearer ab1.nosql-key.nosql-secret"

  body = '{"resource":"customer-orders","limit":2}'
  response = postQuery(port, authHeader, body)
  call assertEq 201, httpStatus(response), "federated query materialized"
  json = httpJson(response)
  queryId = json~at("id")
  call assertTrue queryId~startsWith("qry-"), "query id allocated"
  queryResult = json~at("result")
  call assertEq "customer-orders", queryResult~at("resource"), "logical resource returned"
  call assertEq 2, queryResult~at("row_count"), "server-side bounded LIMIT applied"
  call assertEq "Ada", queryResult~at("rows")~at(1)~at("customer_name"), "federated join row one"
  call assertEq "Grace", queryResult~at("rows")~at(2)~at("customer_name"), "federated join row two"

  evidenceSummary = queryResult~at("query_evidence")
  evidenceId = evidenceSummary~at("evidence_id")
  call assertTrue evidenceId~startsWith(queryId || "-ev-"), "query evidence result scoped"
  evidenceResponse = httpGet(port, authHeader, "/v1/evidence/" || evidenceId)
  call assertEq 200, httpStatus(evidenceResponse), "NoSQL evidence dereference"
  evidenceJson = httpJson(evidenceResponse)
  provenance = evidenceJson~at("provenance")
  call assertEq "NoSQLServer", provenance~at("product"), "provenance product"
  call assertEq nosqlVersion, provenance~at("release"), "provenance release"
  call assertEq "FEDERATED_TABLE_SCAN", provenance~at("access_path"), "federated access path"
  call assertEq 5, provenance~at("rows_scanned"), "rows scanned provenance"
  call assertEq 2, provenance~at("row_count"), "bounded result row count provenance"

  page1 = httpGet(port, authHeader, "/v1/queries/" || queryId || "/rows?limit=1")
  call assertEq 200, httpStatus(page1), "NoSQL page one"
  page1Json = httpJson(page1)
  call assertEq 1, page1Json~at("count"), "NoSQL page one count"
  call assertEq "c.1", page1Json~at("next_cursor"), "NoSQL page cursor"
  page2 = httpGet(port, authHeader, "/v1/queries/" || queryId || "/rows?limit=1&cursor=c.1")
  call assertEq 200, httpStatus(page2), "NoSQL page two"
  call assertEq 1, httpJson(page2)~at("count"), "NoSQL page two count"

  activeSessionResult = abilityRegistry~acquire("prod", "client-nosql"); call mustOk activeSessionResult, "acquire NoSQL profile"
  activeSession = activeSessionResult~value
  dataModule = activeSession~module("data")
  call assertEq 1, dataModule~invocationCount, "paging and evidence do not re-execute NoSQL ability"
  call mustOk activeSession~release, "release NoSQL profile probe"

  /* Raw SQL is not a client authority surface. */
  rawSql = postQuery(port, authHeader, '{"sql":"SELECT * FROM orders"}')
  call assertEq 422, httpStatus(rawSql), "raw SQL-only request rejected"
  unknown = postQuery(port, authHeader, '{"resource":"payroll"}')
  call assertEq 422, httpStatus(unknown), "ungranted logical resource rejected"
  injection = postQuery(port, authHeader, '{"resource":"orders","order_by":["id;DELETE_FROM_orders"]}')
  call assertEq 422, httpStatus(injection), "identifier-shaped SQL injection rejected"

  call mustOk server~stop, "stop NoSQL HTTP server"
  do waitStop = 1 to 500 while server~listening
    call SysSleep 0.01
  end
  call assertFalse server~listening, "NoSQL HTTP server stopped"

  say "  generation=" || staged~generationId
  say "  profile=" || profileGeneration~generationId
  say "  access_path=" || provenance~at("access_path")
  say "  rows_scanned=" || provenance~at("rows_scanned")
  say "ABILITY HTTP NOSQLSERVER V" || nosqlVersion || ": OK"
  return

stageNoSQL:
  procedure
  use arg kernel, verifier, registryRoot, nosqlRoot
  builder = .RuntimeBundleBuilder~new
  call mustOk builder~addFile(nosqlRoot || "/src/NoSQLServer.cls", "NoSQLServer.cls"), "add NoSQLServer source"
  call mustOk builder~addFile(nosqlRoot || "/tests/TestSupport.cls", "TestSupport.cls"), "add NoSQL TestSupport"
  call mustOk builder~addFile(registryRoot || "/fixtures/modules/nosql_ability/RuntimeNoSQLAbility.cls", "RuntimeNoSQLAbility.cls"), "add NoSQL ability wrapper"
  bundleResult = builder~build; call mustOk bundleResult, "build NoSQL ability bundle"; bundle = bundleResult~value
  version = detectNoSQLVersion(nosqlRoot)
  artifactId = "nosqlserver:v" || version || ":ability"
  call mustOk verifier~pin(artifactId, bundle~sourceLines), "pin NoSQL ability"
  artifact = .RuntimeArtifact~new("nosql.data", "SOURCE_PROVIDER", version, artifactId, "RuntimeNoSQLAbility", bundle~sourceLines)
  stagedResult = kernel~stage("prod", artifact); call mustOk stagedResult, "stage NoSQL ability"
  return stagedResult~value

detectNoSQLVersion:
  procedure
  use arg nosqlRoot
  src = .RuntimeSourceLoader~readFile(nosqlRoot || "/src/NoSQLServer.cls")
  if \src~ok then return "unknown"
  inBuild = .false
  do line over src~value
    stripped = line~strip
    upper = stripped~translate
    if upper = "::CLASS NOSQLSERVERBUILD PUBLIC" then do
      inBuild = .true
      iterate
    end
    if inBuild then do
      if upper~startsWith("::CLASS ") then leave
      if upper~startsWith("::CONSTANT RELEASE") then do
        q1 = pos('"', stripped)
        if q1 = 0 then return "unknown"
        q2 = pos('"', stripped, q1 + 1)
        if q2 = 0 then return "unknown"
        return substr(stripped, q1 + 1, q2 - q1 - 1)
      end
    end
  end
  return "unknown"

postQuery:
  procedure
  use arg port, authHeader, bodyText
  headers = .array~of("Host: localhost", authHeader, "Content-Type: application/json", "Content-Length: " || bodyText~length)
  return httpRequest(port, "POST /v1/queries HTTP/1.1", headers, bodyText)

httpGet:
  procedure
  use arg port, authHeader, path
  return httpRequest(port, "GET " || path || " HTTP/1.1", .array~of("Host: localhost", authHeader), "")

httpRequest:
  procedure
  use arg port, requestLine, headers, bodyText
  crlf = "0d0a"x
  requestText = requestLine || crlf
  do i = 1 to headers~items
    requestText = requestText || headers~at(i) || crlf
  end
  requestText = requestText || crlf || bodyText
  socket = .Socket~new
  if socket~connect(.InetAddress~new("127.0.0.1", port)) < 0 then do
    say "FAILED: HTTP client connect" socket~errno
    exit 92
  end
  offset = 1
  do while offset <= requestText~length
    sent = socket~send(substr(requestText, offset))
    if sent == .nil then leave
    if sent <= 0 then leave
    offset = offset + sent
  end
  responseText = ""
  do forever
    chunk = socket~recv(4096)
    if chunk == .nil then leave
    if chunk == "" then leave
    responseText = responseText || chunk
  end
  socket~close
  return responseText

httpStatus:
  procedure
  use arg responseText
  eol = pos("0d0a"x, responseText)
  if eol = 0 then return -1
  return word(left(responseText, eol - 1), 2)

httpBody:
  procedure
  use arg responseText
  marker = "0d0a0d0a"x
  markerPos = pos(marker, responseText)
  if markerPos = 0 then return ""
  return substr(responseText, markerPos + marker~length)

httpJson:
  procedure
  use arg responseText
  return .JSON~fromJSON(httpBody(responseText))

assertEq:
  procedure
  use arg expected, actual, label
  if expected \== actual then do
    say "FAILED:" label "expected=" expected "actual=" actual
    exit 93
  end
  return
assertTrue:
  procedure
  use arg value, label
  if \value then do
    say "FAILED:" label
    exit 94
  end
  return
assertFalse:
  procedure
  use arg value, label
  if value then do
    say "FAILED:" label
    exit 95
  end
  return
mustOk:
  procedure
  use arg operationResult, label
  if \operationResult~ok then do
    say "FAILED:" label operationResult~code operationResult~detail
    exit 96
  end
  return

::requires "AbilityHttpServer.cls"
::requires "RuntimeBundleBuilder.cls"
