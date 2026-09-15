call test_civic_stale_promotion_guard_v019
say "PASS test_civic_stale_promotion_guard_v019"
exit 0

test_civic_stale_promotion_guard_v019:
  root = civicTestTempDir("civic_hw_stale")
  body = readBinary("fixtures/postcodes_io_SW1A1AA.body")
  headers = readBinary("fixtures/postcodes_io_SW1A1AA.headers")
  transport = .CivicTestSequenceTransport~new
  ignore = transport~addHttp(200, "OK", headers, body)
  ignore = transport~addFailure("DNS_FAILURE", "synthetic stale fallback")
  allow = .CivicAllowList~new
  endpoint = .CivicPostcodeAdapter~endpointTemplate
  ignore = allow~add(endpoint~scheme, endpoint~host, endpoint~pathTemplate, endpoint~allowQuery, endpoint~port)
  cache = .CivicCache~new(.CivicClient~new(transport, allow), .CivicJournal~new(root))
  url = "https://api.postcodes.io/postcodes/SW1A%201AA"
  firstFetch = cache~get(url)
  staleFetch = cache~get(url, .nil, 10, "", .true)
  call assertTrue firstFetch~ok, "initial body available"
  call assertEqual "STALE", staleFetch~cacheState, "transport failure resolved to explicit stale cache state"
  observed = .CivicObservationFactory~observe(staleFetch, .CivicPostcodeAdapter~new)
  call assertTrue observed~ok, "stale body can remain evidence"
  civicObservation = observed~observation

  signal on syntax name refused
  badGrant = .CivicPromotionGrant~new("STALE-REFUSED", civicObservation, "country", "CIVIC_COUNTRY", -
    "TEST_AUTHORITY", "STALE-POLICY", "STALE-RULE")
  signal off syntax
  call assertTrue .false, "STALE evidence should require explicit allowStale"

refused:
  signal off syntax
  goodGrant = .CivicPromotionGrant~new("STALE-EXPLICIT", civicObservation, "country", "CIVIC_COUNTRY", -
    "TEST_AUTHORITY", "STALE-POLICY", "STALE-RULE", .true)
  world = .RYTAWorldState~new("CIVIC-STALE-WORLD")
  applyStatus = .CivicPromotionApplier~apply(.array~of(goodGrant), world)
  call assertEqual 1, applyStatus~applied, "STALE promotion is possible only when grant explicitly permits it"
  call assertEqual "England", world~fact("CIVIC_COUNTRY")~value, "explicit stale grant still retains source value"
  return civicTestRemoveTree(root)

::requires "TestSupport.cls"
::requires "CacheTestSupport.cls"
::requires "CivicHardWorld.cls"
