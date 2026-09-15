call test_company_hardworld_v09
say "PASS test_company_hardworld_v09"
exit 0

test_company_hardworld_v09:
  root = civicTestTempDir("civic_company_hw")
  transport = .CivicTestSequenceTransport~new
  ignore = transport~addHttp(200, "OK", readBinary("fixtures/companies_house_fixture.headers"), readBinary("fixtures/companies_house_fixture.body"))
  allow = .CivicAllowList~new
  endpoint = .CivicCompaniesHouseAdapter~endpointTemplate
  ignore = allow~add(endpoint~scheme, endpoint~host, endpoint~pathTemplate, endpoint~allowQuery, endpoint~port)
  cache = .CivicCache~new(.CivicClient~new(transport, allow), .CivicJournal~new(root))
  outcome = cache~get(.CivicCompaniesHouseAdapter~companyUrl("01234567"), .nil, 10, "", .false, "companieshouse-fixture")
  observed = .CivicObservationFactory~observe(outcome, .CivicCompaniesHouseAdapter~new)
  call assertTrue observed~ok, "generic CivicObservationFactory accepts Companies House adapter"
  civicObservation = observed~observation
  call assertEqual "companieshouse.company-profile/0.1", civicObservation~mappingId, "company observation pins mapping generation"
  call assertEqual "companieshouse-fixture", civicObservation~document~request~credentialRef, "company observation retains non-secret credential reference"
  call assertTrue civicObservation~algorithmCanonicalText~pos("companieshouse-fixture") > 0, "company observation canonical evidence includes credential reference"
  call assertTrue \civicObservation~hasField("sic_codes"), "unprojected structured SIC array is not implicitly promotable"

  world = .RYTAWorldState~new("CIVIC-COMPANY-WORLD")
  grant = .CivicPromotionGrant~new("CIVIC-COMPANY-NAME-1", civicObservation, "company_name", "CIVIC_COMPANY_NAME", -
    "TEST_HUMAN_AUTHORITY", "CIVIC-COMPANY-PROMOTION-V1", "NAME_FROM_PINNED_COMPANY_PROFILE")
  call assertTrue \world~hasFact("CIVIC_COMPANY_NAME"), "company observation and grant alone do not change HardWorld"
  applied = .CivicPromotionApplier~apply(.array~of(grant), world)
  call assertEqual 1, applied~applied, "explicit company promotion applies exactly one fact"
  fact = world~fact("CIVIC_COMPANY_NAME")
  call assertEqual "KNOWN", fact~knowledgeState, "company name becomes known only after explicit promotion"
  call assertEqual "CIVICPORT FIXTURE LIMITED", fact~value, "promoted company name is exact lexical value"
  call assertEqual "TEST_HUMAN_AUTHORITY", fact~authority, "Companies House host is not promotion authority"
  call assertTrue fact~evidence~promotions[1]~sourceObject == civicObservation, "HardWorld promotion retains native company observation"
  return civicTestRemoveTree(root)

::requires "TestSupport.cls"
::requires "CacheTestSupport.cls"
::requires "CivicCompaniesHouse.cls"
::requires "CivicHardWorld.cls"
