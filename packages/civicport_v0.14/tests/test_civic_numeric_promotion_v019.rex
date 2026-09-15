call test_civic_numeric_promotion_v019
say "PASS test_civic_numeric_promotion_v019"
exit 0

test_civic_numeric_promotion_v019:
  root = civicTestTempDir("civic_hw_numeric")
  body = '{"status":200,"result":{"postcode":"SW1A 1AA","country":"England","region":null,"longitude":1.2300e+04}}'
  headers = "HTTP/1.1 200 OK" || '0d0a'x || "Content-Type: application/json" || '0d0a0d0a'x
  transport = .CivicTestSequenceTransport~new
  ignore = transport~addHttp(200, "OK", headers, body)
  allow = .CivicAllowList~new
  endpoint = .CivicPostcodeAdapter~endpointTemplate
  ignore = allow~add(endpoint~scheme, endpoint~host, endpoint~pathTemplate, endpoint~allowQuery, endpoint~port)
  cache = .CivicCache~new(.CivicClient~new(transport, allow), .CivicJournal~new(root))
  fetched = cache~get("https://api.postcodes.io/postcodes/SW1A%201AA")
  observed = .CivicObservationFactory~observe(fetched, .CivicPostcodeAdapter~new)
  call assertTrue observed~ok, "numeric fixture maps successfully"
  civicObservation = observed~observation
  call assertEqual "1.2300e+04", civicObservation~field("longitude"), "observation retains ooRexx parser-native number string"
  call assertTrue civicObservation~field("longitude")~class == .String, "JSON number is already an ooRexx String"
  call assertEqual "PRESENT_NULL", civicObservation~fieldState("region"), "explicit JSON null remains distinct from an absent member"
  nullRich = civicObservation~richValue("region")
  call assertEqual "PRESENT_NULL", nullRich~evidenceState, "rich evidence preserves explicit-null state"
  call assertTrue \nullRich~scalarProjectionAllowed, "explicit null is not invented as a scalar"

  grant = .CivicPromotionGrant~new("CIVIC-NUMERIC-1", civicObservation, "longitude", "CIVIC_LONGITUDE_LEXICAL", -
    "TEST_HUMAN_AUTHORITY", "CIVIC-NUMERIC-POLICY", "LONGITUDE_LEXICAL_FROM_PINNED_JSON")
  world = .RYTAWorldState~new("CIVIC-NUMERIC-WORLD")
  applyStatus = .CivicPromotionApplier~apply(.array~of(grant), world)
  call assertEqual 1, applyStatus~applied, "numeric lexical evidence explicitly promoted"
  promoted = world~fact("CIVIC_LONGITUDE_LEXICAL")~value
  call assertEqual "1.2300e+04", promoted, "HardWorld receives exact parser-native numeric lexical string"
  call assertTrue promoted~class == .String, "CivicPort does not introduce a numeric conversion layer"

  return civicTestRemoveTree(root)

::requires "TestSupport.cls"
::requires "CacheTestSupport.cls"
::requires "CivicHardWorld.cls"
