call test_cache_stale
say "PASS test_cache_stale"
exit 0

test_cache_stale:
  root = civicTestTempDir("civic_stale")
  body = readBinary("fixtures/postcodes_io_SW1A1AA.body")
  headers200 = readBinary("fixtures/postcodes_io_SW1A1AA.headers")
  allow = .CivicAllowList~new
  ignore = allow~add("https", "api.postcodes.io", "/postcodes/{postcode}")
  transport = .CivicTestSequenceTransport~new
  ignore = transport~addHttp(200, "OK", headers200, body)
  ignore = transport~addFailure("HTTP_TRANSPORT_ERROR", "offline")
  cache = .CivicCache~new(.CivicClient~new(transport, allow), .CivicJournal~new(root))
  url = "https://api.postcodes.io/postcodes/SW1A%201AA"

  firstFetch = cache~get(url)
  staleFetch = cache~get(url, .nil, 10, "", .true)
  call assertTrue staleFetch~ok, "explicit stale fallback succeeds after transport failure"
  call assertEqual "STALE", staleFetch~cacheState, "stale fallback is labelled"
  call assertEqual firstFetch~bodyRecordId, staleFetch~bodyRecordId, "stale fallback names original body record"
  call assertEqual firstFetch~document~bodyDigest, staleFetch~document~bodyDigest, "stale fallback does not mint or mutate body evidence"
  call assertTrue staleFetch~observation == .nil, "transport failure creates no CivicDocument observation"
  call assertEqual "HTTP_TRANSPORT_ERROR", staleFetch~staleReasonCode, "stale result retains transport failure code"
  call assertEqual "offline", staleFetch~staleReasonMessage, "stale result retains transport failure message"
  call assertEqual 1, cache~journal~count, "transport failure adds no journal document"
  return civicTestRemoveTree(root)

::requires "TestSupport.cls"
::requires "CacheTestSupport.cls"
