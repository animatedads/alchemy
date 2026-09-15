call test_cache_refresh
say "PASS test_cache_refresh"
exit 0

test_cache_refresh:
  root = civicTestTempDir("civic_refresh")
  body1 = '{"status":200,"result":{"postcode":"SW1A 1AA","country":"England"}}'
  body2 = '{"status":200,"result":{"postcode":"SW1A 2AA","country":"England"}}'
  h1 = "HTTP/1.1 200 OK" || '0d0a'x || "Content-Type: application/json" || '0d0a'x || 'ETag: "gen-1"' || '0d0a0d0a'x
  h2 = "HTTP/1.1 200 OK" || '0d0a'x || "Content-Type: application/json" || '0d0a'x || 'ETag: "gen-2"' || '0d0a0d0a'x

  allow = .CivicAllowList~new
  ignore = allow~add("https", "api.postcodes.io", "/postcodes/{postcode}")
  transport = .CivicTestSequenceTransport~new
  ignore = transport~addHttp(200, "OK", h1, body1)
  ignore = transport~addHttp(200, "OK", h2, body2)
  cache = .CivicCache~new(.CivicClient~new(transport, allow), .CivicJournal~new(root))
  url = "https://api.postcodes.io/postcodes/SW1A%201AA"

  firstFetch = cache~get(url)
  secondFetch = cache~get(url)
  call assertEqual "MISS", firstFetch~cacheState, "first 200 is miss"
  call assertEqual "FRESH", secondFetch~cacheState, "new 200 replacing existing entity is fresh"
  call assertTrue firstFetch~bodyRecordId \== secondFetch~bodyRecordId, "changed 200 mints a new body record"
  call assertTrue firstFetch~document~bodyDigest \== secondFetch~document~bodyDigest, "new representation has a new exact-body digest"
  call assertEqual "SW1A 2AA", secondFetch~document~parsed["result"]["postcode"], "new body is the projectable representation"
  call assertEqual '"gen-1"', transport~request(2)~headers~first("If-None-Match"), "refresh request carries prior validator"
  return civicTestRemoveTree(root)

::requires "TestSupport.cls"
::requires "CacheTestSupport.cls"
