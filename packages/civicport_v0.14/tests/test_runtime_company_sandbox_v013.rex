call test_runtime_company_sandbox_v013
say "PASS test_runtime_company_sandbox_v013"
exit 0

test_runtime_company_sandbox_v013:
  contract = .CivicCompanySandboxApiContract~new
  call assertEqual "SANDBOX", contract~sourceEnvironment, "sandbox Runtime contract environment pinned"
  call assertEqual "civic.company.lookup.sandbox/0.1", contract~contractGeneration, "sandbox Runtime contract generation distinct"
  call assertEqual "companieshouse.company-profile/0.1", contract~mappingGeneration, "sandbox shares response mapping generation only"
  call assertEqual "civic.company.lookup.sandbox", contract~abilityId, "sandbox ability id distinct"
  call assertEqual "civicport-company-sandbox", contract~profileId, "sandbox profile family distinct"

  descriptor = contract~descriptor("civic")
  call assertTrue descriptor~readOnly, "sandbox company ability is read only"
  good = .directory~new
  good["company_number"] = .JsonString~new("01234567")
  call assertTrue descriptor~validateInput(good)~ok, "sandbox company input validates"
  extra = good~copy
  extra["url"] = "https://api.company-information.service.gov.uk/company/01234567"
  call assertTrue \descriptor~validateInput(extra)~ok, "Runtime caller cannot override sandbox endpoint"

  root = civicTestTempDir("civic_company_sandbox_contract_v013")
  transport = .CivicTestSequenceTransport~new
  ignore = transport~addHttp(200, "OK", readBinary("fixtures/companies_house_fixture.headers"), readBinary("fixtures/companies_house_fixture.body"))
  allow = .CivicAllowList~new
  endpoint = .CivicCompaniesHouseSandboxAdapter~endpointTemplate
  ignore = allow~add(endpoint~scheme, endpoint~host, endpoint~pathTemplate, endpoint~allowQuery, endpoint~port)
  client = .CivicClient~new(transport, allow)
  cache = .CivicCache~new(client, .CivicJournal~new(root))
  outcome = cache~get(.CivicCompaniesHouseSandboxAdapter~companyUrl("01234567"), .nil, 10, "", .false, "companieshouse-sandbox-fixture")
  call assertTrue outcome~ok, "sandbox company fixture cache fetch succeeds"

  output = contract~projectCacheResult(outcome)
  check = descriptor~validateOutput(output)
  call assertTrue check~ok, "sandbox company evidence satisfies exact output schema"
  call assertEqual "civic.company.lookup.sandbox/0.1", output["contract_generation"], "sandbox output carries sandbox contract generation"
  call assertEqual "companieshouse.company-profile/0.1", output["mapping_generation"], "sandbox output carries shared mapping generation"
  call assertEqual "companieshouse-sandbox-fixture", output["credential_reference"], "sandbox output carries only non-secret credential reference"
  call assertTrue output["source_url"]~pos("api-sandbox.company-information.service.gov.uk") > 0, "sandbox evidence remains on sandbox host"

  liveRoot = civicTestTempDir("civic_company_live_cross_v013")
  liveTransport = .CivicTestSequenceTransport~new
  ignore = liveTransport~addHttp(200, "OK", readBinary("fixtures/companies_house_fixture.headers"), readBinary("fixtures/companies_house_fixture.body"))
  liveAllow = .CivicAllowList~new
  liveEndpoint = .CivicCompaniesHouseAdapter~endpointTemplate
  ignore = liveAllow~add(liveEndpoint~scheme, liveEndpoint~host, liveEndpoint~pathTemplate)
  liveCache = .CivicCache~new(.CivicClient~new(liveTransport, liveAllow), .CivicJournal~new(liveRoot))
  liveOutcome = liveCache~get(.CivicCompaniesHouseAdapter~companyUrl("01234567"), .nil, 10, "", .false, "companieshouse-live-fixture")
  call assertTrue liveOutcome~ok, "live fixture produced for cross-domain rejection"

  rejected = .false
  signal on syntax name liveRejected
  bad = contract~projectCacheResult(liveOutcome)
  signal off syntax
  call assertTrue .false, "sandbox Runtime contract must reject live-host evidence"
liveRejected:
  signal off syntax
  rejected = .true
  call assertTrue rejected, "sandbox Runtime contract rejects live-host evidence"

  pin = contract~profilePin("civic-test-client", "1", "civic", "tests/RuntimeCivicContractFixture_v1.cls", "company-sandbox-handler-v1")
  call assertEqual "civicport-company-sandbox", pin~profile~profileId, "sandbox profile identity cannot collide with live profile"

  ignore = civicTestRemoveTree(root)
  ignore = civicTestRemoveTree(liveRoot)
  return

::requires "TestSupport.cls"
::requires "CacheTestSupport.cls"
::requires "CivicCompaniesHouseRuntime.cls"
