call test_civic_promotion_v019
say "PASS test_civic_promotion_v019"
exit 0

test_civic_promotion_v019:
  root = civicTestTempDir("civic_hw_promote")
  body = readBinary("fixtures/postcodes_io_SW1A1AA.body")
  headers = readBinary("fixtures/postcodes_io_SW1A1AA.headers")
  transport = .CivicTestSequenceTransport~new
  ignore = transport~addHttp(200, "OK", headers, body)
  allow = .CivicAllowList~new
  endpoint = .CivicPostcodeAdapter~endpointTemplate
  ignore = allow~add(endpoint~scheme, endpoint~host, endpoint~pathTemplate, endpoint~allowQuery, endpoint~port)
  cache = .CivicCache~new(.CivicClient~new(transport, allow), .CivicJournal~new(root))
  cacheOutcome = cache~get("https://api.postcodes.io/postcodes/SW1A%201AA")
  observed = .CivicObservationFactory~observe(cacheOutcome, .CivicPostcodeAdapter~new)
  call assertTrue observed~ok, "observation available for explicit promotion"
  civicObservation = observed~observation

  call assertTrue grantWithoutAuthorityRejected(civicObservation), "promotion grant requires non-network explicit authority"
  world = .RYTAWorldState~new("CIVIC-PROMOTION-WORLD")
  grant = .CivicPromotionGrant~new("CIVIC-PROMO-COUNTRY-1", civicObservation, "country", "CIVIC_COUNTRY", -
    "TEST_HUMAN_AUTHORITY", "CIVIC-POSTCODE-PROMOTION-V1", "COUNTRY_FROM_PINNED_POSTCODE")
  call assertTrue \world~hasFact("CIVIC_COUNTRY"), "grant construction alone does not change HardWorld"

  applyStatus = .CivicPromotionApplier~apply(.array~of(grant), world)
  call assertEqual 1, applyStatus~applied, "explicit grant applies one HardWorld fact"
  call assertEqual 0, applyStatus~conflicts, "single promotion is not conflicting"
  call assertTrue world~hasFact("CIVIC_COUNTRY"), "world gains fact only after explicit apply"
  fact = world~fact("CIVIC_COUNTRY")
  call assertEqual "KNOWN", fact~knowledgeState, "present civic scalar becomes KNOWN only after grant"
  call assertEqual "England", fact~value, "promoted value is exact parser-native string"
  call assertEqual "EVIDENCE_PROMOTION", fact~source, "HardWorld records generic promotion boundary"
  call assertEqual "TEST_HUMAN_AUTHORITY", fact~authority, "network host is not authority"
  bundle = fact~evidence
  call assertEqual 1, bundle~promotions~items, "HardWorld evidence retains promotion bundle"
  promotion = bundle~promotions[1]
  call assertTrue promotion~sourceObject == civicObservation, "promotion reaches native CivicObservation"
  call assertTrue promotion~evidence~nativeObject == civicObservation, "rich promotion evidence retains observation"
  call assertEqual "CIVIC-POSTCODE-PROMOTION-V1", promotion~policyId, "explicit policy id retained"
  call assertEqual "COUNTRY_FROM_PINNED_POSTCODE", promotion~ruleId, "explicit rule id retained"
  call assertEqual civicObservation~identity, promotion~sourceIdentity, "promotion pins exact observation identity"

  /* Missing source member is not converted into a known nil value. */
  missingGrant = .CivicPromotionGrant~new("CIVIC-PROMO-REGION-1", civicObservation, "region", "CIVIC_REGION", -
    "TEST_HUMAN_AUTHORITY", "CIVIC-POSTCODE-PROMOTION-V1", "REGION_FROM_PINNED_POSTCODE")
  missingApply = .CivicPromotionApplier~apply(.array~of(missingGrant), world)
  call assertEqual 1, missingApply~applied, "explicit absent-field grant applies an epistemic fact"
  call assertTrue world~hasFact("CIVIC_REGION"), "absent field produces explicit world entry"
  call assertEqual "UNKNOWN", world~fact("CIVIC_REGION")~knowledgeState, "missing JSON member promotes UNKNOWN, never known nil"

  return civicTestRemoveTree(root)


grantWithoutAuthorityRejected: procedure
  use arg civicObservation
  signal on syntax name rejected
  badGrant = .CivicPromotionGrant~new("NO-AUTH", civicObservation, "country", "CIVIC_COUNTRY", "", "POLICY", "RULE")
  signal off syntax
  return .false
rejected:
  signal off syntax
  return .true

::requires "TestSupport.cls"
::requires "CacheTestSupport.cls"
::requires "CivicHardWorld.cls"
