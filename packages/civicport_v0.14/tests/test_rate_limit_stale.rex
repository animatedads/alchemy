call test_rate_limit_stale
say "PASS test_rate_limit_stale"
exit 0

test_rate_limit_stale:
  root = civicTestTempDir("civic_rate")
  body = readBinary("fixtures/postcodes_io_SW1A1AA.body")
  headers200 = readBinary("fixtures/postcodes_io_SW1A1AA.headers")
  headers429 = "HTTP/1.1 429 Too Many Requests" || '0d0a'x || -
    "Content-Type: application/json" || '0d0a'x || -
    "Retry-After: 60" || '0d0a0d0a'x
  body429 = '{"status":429,"error":"rate limit"}'

  allow = .CivicAllowList~new
  ignore = allow~add("https", "api.postcodes.io", "/postcodes/{postcode}")
  transport = .CivicTestSequenceTransport~new
  ignore = transport~addHttp(200, "OK", headers200, body)
  ignore = transport~addHttp(429, "Too Many Requests", headers429, body429)
  journal = .CivicJournal~new(root)
  cache = .CivicCache~new(.CivicClient~new(transport, allow), journal)
  url = "https://api.postcodes.io/postcodes/SW1A%201AA"

  firstFetch = cache~get(url)
  staleFetch = cache~get(url, .nil, 10, "", .true)
  call assertTrue staleFetch~ok, "explicit rate-limit fallback serves cached entity"
  call assertEqual "STALE", staleFetch~cacheState, "rate-limit fallback is labelled stale"
  call assertEqual firstFetch~bodyRecordId, staleFetch~bodyRecordId, "429 does not replace cached body"
  call assertTrue staleFetch~observation \== .nil, "429 remains a real CivicDocument observation"
  call assertEqual 429, staleFetch~observation~status, "429 status retained"
  call assertEqual "60", staleFetch~observation~header("Retry-After"), "Retry-After remains evidence"
  call assertEqual body429, staleFetch~observation~bodyBytes, "429 body bytes are preserved exactly"
  call assertEqual "HTTP_429", staleFetch~staleReasonCode, "stale reason identifies rate limiting"
  call assertEqual "Too Many Requests", staleFetch~staleReasonMessage, "stale reason retains HTTP reason"
  call assertEqual 2, journal~count, "both 200 and 429 observations are journaled"
  return civicTestRemoveTree(root)

::requires "TestSupport.cls"
::requires "CacheTestSupport.cls"
