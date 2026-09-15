call test_access_state_v07
say "PASS test_access_state_v07"
exit 0

test_access_state_v07:
  body = readBinary("fixtures/postcodes_io_SW1A1AA.body")
  headers200 = readBinary("fixtures/postcodes_io_SW1A1AA.headers")
  url = "https://api.postcodes.io/postcodes/SW1A%201AA"

  rootHealthy = civicTestTempDir("civic_access_healthy")
  transportHealthy = .CivicTestSequenceTransport~new
  ignore = transportHealthy~addHttp(200, "OK", headers200, body)
  healthy = makeCache(rootHealthy, transportHealthy)~get(url)
  h = healthy~accessState
  call assertEqual "HEALTHY", h~state, "200 evidence is operationally healthy"
  call assertEqual "NONE", h~cause, "healthy result has no degradation cause"
  call assertEqual "200", h~bodyStatus, "body status retained separately"
  call assertEqual "200", h~observationStatus, "initial body is also network observation"
  call assertTrue h~hasBody, "healthy access has a document"
  call assertTrue h~hasObservation, "healthy access has a network observation"
  call assertTrue \h~rateLimited, "healthy access is not rate limited"
  call assertEqual "", h~retryAfter, "no Retry-After invented"
  ignore = civicTestRemoveTree(rootHealthy)

  rootRate = civicTestTempDir("civic_access_rate")
  headers429 = "HTTP/1.1 429 Too Many Requests" || '0d0a'x || -
    "Content-Type: application/json" || '0d0a'x || -
    "Retry-After: 00060" || '0d0a0d0a'x
  transportRate = .CivicTestSequenceTransport~new
  ignore = transportRate~addHttp(200, "OK", headers200, body)
  ignore = transportRate~addHttp(429, "Too Many Requests", headers429, '{"status":429,"error":"rate limit"}')
  cacheRate = makeCache(rootRate, transportRate)
  first = cacheRate~get(url)
  rate = cacheRate~get(url, .nil, 10, "", .true)
  r = rate~accessState
  call assertEqual "DEGRADED", r~state, "429 stale fallback is degraded"
  call assertEqual "RATE_LIMIT", r~cause, "429 cause is explicit"
  call assertTrue r~rateLimited, "rate-limit dimension is explicit"
  call assertTrue r~servedStale, "stale entity dimension is explicit"
  call assertEqual "200", r~bodyStatus, "stale body remains earlier 200"
  call assertEqual "429", r~observationStatus, "latest observation remains 429"
  call assertEqual "00060", r~retryAfter, "Retry-After remains exact lexical evidence"
  call assertEqual "HTTP_429", r~staleReasonCode, "rate-limit stale reason retained"
  call assertEqual first~bodyRecordId, r~bodyRecordId, "rate limit cannot replace body identity"
  call assertTrue r~observationRecordId \= r~bodyRecordId, "429 has its own journal record"
  call assertTrue r~algorithmCanonicalText~pos("RETRY_AFTER=5:00060") > 0, "canonical state preserves Retry-After lexical form"
  ignore = civicTestRemoveTree(rootRate)

  rootTransport = civicTestTempDir("civic_access_transport")
  transportFail = .CivicTestSequenceTransport~new
  ignore = transportFail~addHttp(200, "OK", headers200, body)
  ignore = transportFail~addFailure("DNS_UNAVAILABLE", "resolver unavailable")
  cacheFail = makeCache(rootTransport, transportFail)
  ignore = cacheFail~get(url)
  stale = cacheFail~get(url, .nil, 10, "", .true)
  s = stale~accessState
  call assertEqual "DEGRADED", s~state, "transport stale fallback is degraded"
  call assertEqual "TRANSPORT_FAILURE", s~cause, "transport failure cause retained"
  call assertEqual "DNS_UNAVAILABLE", s~staleReasonCode, "transport failure code retained"
  call assertEqual "resolver unavailable", s~staleReasonMessage, "transport failure message retained"
  call assertTrue \s~hasObservation, "transport failure does not manufacture an HTTP observation"
  ignore = civicTestRemoveTree(rootTransport)

  rootCold = civicTestTempDir("civic_access_cold")
  coldTransport = .CivicTestSequenceTransport~new
  ignore = coldTransport~addFailure("CONNECT_FAILED", "connection failed")
  cold = makeCache(rootCold, coldTransport)~get(url)
  call assertTrue \cold~ok, "cold transport failure remains fetch failure"
  c = cold~accessState
  call assertEqual "UNAVAILABLE", c~state, "cold transport failure is unavailable"
  call assertEqual "TRANSPORT_FAILURE", c~cause, "cold failure cause retained"
  call assertTrue \c~hasBody, "cold transport failure has no document"
  call assertTrue \c~hasObservation, "cold transport failure has no observation"
  ignore = civicTestRemoveTree(rootCold)

  rootServer = civicTestTempDir("civic_access_server")
  headers503 = "HTTP/1.1 503 Service Unavailable" || '0d0a'x || "Content-Type: application/json" || '0d0a0d0a'x
  serverTransport = .CivicTestSequenceTransport~new
  ignore = serverTransport~addHttp(503, "Service Unavailable", headers503, '{"status":503}')
  server = makeCache(rootServer, serverTransport)~get(url)
  call assertTrue server~ok, "503 remains an HTTP evidence document"
  sv = server~accessState
  call assertEqual "DEGRADED", sv~state, "5xx response is degraded service evidence"
  call assertEqual "HTTP_SERVER_ERROR", sv~cause, "5xx cause is explicit"
  call assertEqual "503", sv~bodyStatus, "503 body status retained"
  call assertEqual "503", sv~observationStatus, "503 observation status retained"
  ignore = civicTestRemoveTree(rootServer)

  rootNotFound = civicTestTempDir("civic_access_notfound")
  headers404 = "HTTP/1.1 404 Not Found" || '0d0a'x || "Content-Type: application/json" || '0d0a0d0a'x
  notFoundTransport = .CivicTestSequenceTransport~new
  ignore = notFoundTransport~addHttp(404, "Not Found", headers404, '{"status":404}')
  notFound = makeCache(rootNotFound, notFoundTransport)~get(url)
  call assertTrue notFound~ok, "404 remains an HTTP evidence document"
  nf = notFound~accessState
  call assertEqual "HEALTHY", nf~state, "ordinary 4xx evidence is not mislabelled service degradation"
  call assertEqual "NONE", nf~cause, "404 has no operational degradation cause"
  call assertEqual "404", nf~observationStatus, "404 status remains visible evidence"
  ignore = civicTestRemoveTree(rootNotFound)

  rootBlocked = civicTestTempDir("civic_access_blocked")
  blockedTransport = .CivicTestSequenceTransport~new
  blockedCache = makeCache(rootBlocked, blockedTransport)
  blocked = blockedCache~get("https://evil.example/postcodes/SW1A%201AA")
  call assertTrue \blocked~ok, "disallowed URL remains blocked before transport"
  b = blocked~accessState
  call assertEqual "BLOCKED", b~state, "local policy refusal is not remote outage"
  call assertEqual "LOCAL_POLICY", b~cause, "policy cause explicit"
  call assertEqual 0, blockedTransport~requestCount, "blocked state performs no transport"
  return civicTestRemoveTree(rootBlocked)

makeCache: procedure
  use arg root, transport
  allow = .CivicAllowList~new
  endpoint = .CivicPostcodeAdapter~endpointTemplate
  ignore = allow~add(endpoint~scheme, endpoint~host, endpoint~pathTemplate, endpoint~allowQuery, endpoint~port)
  return .CivicCache~new(.CivicClient~new(transport, allow), .CivicJournal~new(root))

::requires "TestSupport.cls"
::requires "CacheTestSupport.cls"
::requires "CivicPostcode.cls"
