call test_civic_access_hardworld_v023
say "PASS test_civic_access_hardworld_v023"
exit 0

test_civic_access_hardworld_v023:
  root = civicTestTempDir("civic_hw_access")
  body = readBinary("fixtures/postcodes_io_SW1A1AA.body")
  headers200 = readBinary("fixtures/postcodes_io_SW1A1AA.headers")
  headers429 = "HTTP/1.1 429 Too Many Requests" || '0d0a'x || -
    "Content-Type: application/json" || '0d0a'x || -
    "Retry-After: Wed, 21 Oct 2015 07:28:00 GMT" || '0d0a0d0a'x
  transport = .CivicTestSequenceTransport~new
  ignore = transport~addHttp(200, "OK", headers200, body)
  ignore = transport~addHttp(429, "Too Many Requests", headers429, '{"status":429,"error":"rate limit"}')
  allow = .CivicAllowList~new
  endpoint = .CivicPostcodeAdapter~endpointTemplate
  ignore = allow~add(endpoint~scheme, endpoint~host, endpoint~pathTemplate, endpoint~allowQuery, endpoint~port)
  cache = .CivicCache~new(.CivicClient~new(transport, allow), .CivicJournal~new(root))
  url = "https://api.postcodes.io/postcodes/SW1A%201AA"
  ignore = cache~get(url)
  degraded = cache~get(url, .nil, 10, "", .true)

  observed = .CivicObservationFactory~observe(degraded, .CivicPostcodeAdapter~new)
  call assertTrue observed~ok, "degraded stale entity can become evidence observation"
  civicObservation = observed~observation
  access = civicObservation~accessState
  call assertEqual "DEGRADED", access~state, "HardWorld bridge sees degraded state"
  call assertEqual "RATE_LIMIT", access~cause, "HardWorld bridge sees rate-limit cause"
  call assertEqual "Wed, 21 Oct 2015 07:28:00 GMT", access~retryAfter, "HTTP-date Retry-After remains uninterpreted lexical evidence"
  canonical = civicObservation~algorithmCanonicalText
  call assertTrue canonical~pos("ACCESS_STATE=8:DEGRADED") > 0, "observation canonical evidence includes access state"
  call assertTrue canonical~pos("DEGRADATION_CAUSE=10:RATE_LIMIT") > 0, "observation canonical evidence includes degradation cause"
  call assertTrue canonical~pos("RETRY_AFTER=29:Wed, 21 Oct 2015 07:28:00 GMT") > 0, "observation canonical evidence includes exact Retry-After"

  world = .RYTAWorldState~new("CIVIC-ACCESS-WORLD")
  grant = .CivicPromotionGrant~new("CIVIC-ACCESS-COUNTRY", civicObservation, "country", "CIVIC_COUNTRY", -
    "TEST_ACCESS_AUTHORITY", "CIVIC-ACCESS-POLICY", "COUNTRY_FROM_DEGRADED_EVIDENCE", .true)
  applied = .CivicPromotionApplier~apply(.array~of(grant), world)
  call assertEqual 1, applied~applied, "explicit stale grant remains required and can apply"
  promotion = world~fact("CIVIC_COUNTRY")~evidence~promotions[1]
  foundAccess = .false
  do basis over promotion~basis
    if basis~basisKind = "CIVIC_ACCESS_STATE" then do
      foundAccess = .true
      call assertEqual "DEGRADED", basis~basisId, "promotion basis pins access state"
      call assertTrue basis~detail~pos("RATE_LIMIT") > 0, "promotion basis carries degradation cause"
      call assertTrue basis~nativeObject == access, "promotion basis retains native CivicAccessState"
    end
  end
  call assertTrue foundAccess, "promotion evidence includes CIVIC_ACCESS_STATE basis"
  ignore = civicTestRemoveTree(root)

  /* Two transport failures over the same cached body must remain distinct evidence. */
  root2 = civicTestTempDir("civic_hw_access_transport_identity")
  transport2 = .CivicTestSequenceTransport~new
  ignore = transport2~addHttp(200, "OK", headers200, body)
  ignore = transport2~addFailure("DNS_UNAVAILABLE", "resolver unavailable")
  ignore = transport2~addFailure("TLS_FAILURE", "certificate path failed")
  allow2 = .CivicAllowList~new
  ignore = allow2~add(endpoint~scheme, endpoint~host, endpoint~pathTemplate, endpoint~allowQuery, endpoint~port)
  cache2 = .CivicCache~new(.CivicClient~new(transport2, allow2), .CivicJournal~new(root2))
  ignore = cache2~get(url)
  staleA = cache2~get(url, .nil, 10, "", .true)
  staleB = cache2~get(url, .nil, 10, "", .true)
  obsA = .CivicObservationFactory~observe(staleA, .CivicPostcodeAdapter~new)~observation
  obsB = .CivicObservationFactory~observe(staleB, .CivicPostcodeAdapter~new)~observation
  call assertEqual obsA~bodyRecordId, obsB~bodyRecordId, "transport failures reuse the same cached body"
  call assertEqual "", obsA~observationRecordId, "transport failure has no invented HTTP journal record"
  call assertEqual "", obsB~observationRecordId, "second transport failure also has no HTTP journal record"
  call assertTrue obsA~accessState~identity \== obsB~accessState~identity, "different transport failures have distinct access-state identities"
  call assertTrue obsA~identity \== obsB~identity, "frozen CivicObservation identity includes degradation evidence"
  call assertTrue obsA~identity~startsWith("CIVICOBS-V2:"), "v0.7 observation identity generation is explicit"
  return civicTestRemoveTree(root2)

::requires "TestSupport.cls"
::requires "CacheTestSupport.cls"
::requires "CivicHardWorld.cls"
