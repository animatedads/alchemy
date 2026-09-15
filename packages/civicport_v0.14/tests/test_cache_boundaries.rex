call test_cache_boundaries
say "PASS test_cache_boundaries"
exit 0

test_cache_boundaries:
  root = civicTestTempDir("civic_cache_boundary")
  allow = .CivicAllowList~new
  ignore = allow~add("https", "api.postcodes.io", "/postcodes/{postcode}")
  transport = .CivicTestSequenceTransport~new
  journal = .CivicJournal~new(root)
  cache = .CivicCache~new(.CivicClient~new(transport, allow), journal)

  blocked = cache~get("https://evil.example/postcodes/SW1A%201AA")
  call assertTrue \blocked~ok, "cached GET cannot bypass client allow-list"
  call assertEqual "URL_NOT_ALLOWED", blocked~errorCode, "cache allow-list rejection remains explicit"
  call assertEqual 0, transport~requestCount, "disallowed cache URL never reaches transport"
  call assertEqual 0, journal~count, "disallowed cache URL creates no journal record"

  headers = .directory~new
  headers["Accept-Language"] = "en-GB"
  varied = cache~get("https://api.postcodes.io/postcodes/SW1A%201AA", headers)
  call assertTrue \varied~ok, "cached GET refuses unkeyed representation-varying caller headers"
  call assertEqual "CACHE_REQUEST_HEADERS_UNSUPPORTED", varied~errorCode, "unkeyed request-header refusal is explicit"
  call assertEqual 0, transport~requestCount, "unkeyed caller headers do not reach transport"
  call assertEqual 0, journal~count, "unkeyed caller headers create no journal evidence"

  return civicTestRemoveTree(root)

::requires "TestSupport.cls"
::requires "CacheTestSupport.cls"
