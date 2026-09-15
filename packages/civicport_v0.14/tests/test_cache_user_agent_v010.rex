call test_cache_user_agent_v010
say "PASS test_cache_user_agent_v010"
exit 0

test_cache_user_agent_v010:
  url = .CivicAviationWeatherAdapter~metarUrl("EGLL")
  headersA = .directory~new
  headersA["User-Agent"] = "CivicPort/0.10"
  headersB = .directory~new
  headersB["User-Agent"] = "AnotherCivicClient/1"
  keyA = .CivicCacheKey~forRequest(.CivicRequest~new(url, "GET", headersA))
  keyB = .CivicCacheKey~forRequest(.CivicRequest~new(url, "GET", headersB))
  call assertTrue keyA \== keyB, "different User-Agent evidence produces different cache identity"
  call assertTrue keyA~pos(c2x("CivicPort/0.10")) > 0, "cache identity preserves exact User-Agent lexical bytes as hex"

  root = civicTestTempDir("civic_cache_user_agent_v010")
  allow = .CivicAllowList~new
  endpoint = .CivicAviationWeatherAdapter~endpointTemplate
  ignore = allow~add(endpoint~scheme, endpoint~host, endpoint~pathTemplate, endpoint~allowQuery, endpoint~port, endpoint~queryTemplate)
  transport = .CivicTestSequenceTransport~new
  ignore = transport~addHttp(200, "OK", readBinary("fixtures/aviationweather_EGLL_fixture.headers"), readBinary("fixtures/aviationweather_EGLL_fixture.body"))
  cache = .CivicCache~new(.CivicClient~new(transport, allow), .CivicJournal~new(root))
  outcome = cache~get(url, headersA)
  call assertTrue outcome~ok, "cache accepts one key-partitioned User-Agent"
  call assertEqual "CivicPort/0.10", transport~request(1)~headers~first("User-Agent"), "User-Agent is retained request evidence"
  call assertEqual "CivicPort/0.10", outcome~document~request~headers~first("User-Agent"), "journalled document retains User-Agent evidence"

  unsupported = .directory~new
  unsupported["Accept-Language"] = "en-GB"
  refused = cache~get(url, unsupported)
  call assertTrue \refused~ok, "other caller headers remain unsupported"
  call assertEqual "CACHE_REQUEST_HEADERS_UNSUPPORTED", refused~errorCode, "non-User-Agent header refusal remains explicit"
  call assertEqual 1, transport~requestCount, "blocked representation header performs no transport request"
  return civicTestRemoveTree(root)

::requires "TestSupport.cls"
::requires "CacheTestSupport.cls"
::requires "CivicAviationWeather.cls"
