call test_civic_revalidated_promotion_v019
say "PASS test_civic_revalidated_promotion_v019"
exit 0

test_civic_revalidated_promotion_v019:
  root = civicTestTempDir("civic_hw_304")
  body = readBinary("fixtures/postcodes_io_SW1A1AA.body")
  headers200 = readBinary("fixtures/postcodes_io_SW1A1AA.headers")
  headers304 = "HTTP/1.1 304 Not Modified" || '0d0a'x || -
    'ETag: "civicport-v01-fixture"' || '0d0a'x || -
    "Date: Thu, 20 Aug 2026 20:00:00 GMT" || '0d0a0d0a'x
  transport = .CivicTestSequenceTransport~new
  ignore = transport~addHttp(200, "OK", headers200, body)
  ignore = transport~addHttp(304, "Not Modified", headers304, "")
  allow = .CivicAllowList~new
  endpoint = .CivicPostcodeAdapter~endpointTemplate
  ignore = allow~add(endpoint~scheme, endpoint~host, endpoint~pathTemplate, endpoint~allowQuery, endpoint~port)
  cache = .CivicCache~new(.CivicClient~new(transport, allow), .CivicJournal~new(root))
  url = "https://api.postcodes.io/postcodes/SW1A%201AA"
  firstFetch = cache~get(url)
  secondFetch = cache~get(url)
  call assertEqual "REVALIDATED", secondFetch~cacheState, "fixture produced 304 revalidation"

  observed = .CivicObservationFactory~observe(secondFetch, .CivicPostcodeAdapter~new)
  call assertTrue observed~ok, "revalidated cache result becomes CivicObservation"
  civicObservation = observed~observation
  call assertEqual 200, civicObservation~document~status, "observation body remains original 200"
  call assertEqual 304, civicObservation~httpObservation~status, "new 304 remains distinct HTTP observation"
  call assertEqual firstFetch~bodyRecordId, civicObservation~bodyRecordId, "observation pins earlier body record"
  call assertTrue civicObservation~observationRecordId \= civicObservation~bodyRecordId, "304 has distinct observation record id"
  call assertTrue civicObservation~algorithmCanonicalText~pos("OBS_STATUS=3:304") > 0, "canonical evidence includes 304 observation"

  world = .RYTAWorldState~new("CIVIC-304-PROMOTION-WORLD")
  grant = .CivicPromotionGrant~new("CIVIC-304-COUNTRY", civicObservation, "country", "CIVIC_COUNTRY", -
    "TEST_REVALIDATION_AUTHORITY", "CIVIC-304-POLICY", "COUNTRY_FROM_REVALIDATED_BODY")
  applyStatus = .CivicPromotionApplier~apply(.array~of(grant), world)
  call assertEqual 1, applyStatus~applied, "revalidated body can be explicitly promoted"
  promotion = world~fact("CIVIC_COUNTRY")~evidence~promotions[1]
  call assertTrue promotion~sourceObject~httpObservation == secondFetch~observation, "HardWorld evidence reaches distinct 304 document"
  call assertEqual firstFetch~document~bodyDigest, promotion~sourceObject~document~bodyDigest, "HardWorld evidence still reaches original body identity"

  return civicTestRemoveTree(root)

::requires "TestSupport.cls"
::requires "CacheTestSupport.cls"
::requires "CivicHardWorld.cls"
