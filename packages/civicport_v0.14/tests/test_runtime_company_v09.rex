call test_runtime_company_v09
say "PASS test_runtime_company_v09"
exit 0

test_runtime_company_v09:
  call assertTrue .CivicCompanyApiContract~isSubclassOf(.AlchemyObject), "company API contract inherits house base"
  contract = .CivicCompanyApiContract~new
  call assertEqual "civic.company.lookup/0.1", contract~contractGeneration, "company API contract generation pinned"
  call assertEqual "companieshouse.company-profile/0.1", contract~mappingGeneration, "company mapping generation pinned"
  call assertEqual "civic.company.lookup", contract~abilityId, "company ability id pinned"

  descriptor = contract~descriptor("civic")
  call assertTrue descriptor~readOnly, "company ability is read only"
  good = .directory~new
  good["company_number"] = .JsonString~new("01234567")
  call assertTrue descriptor~validateInput(good)~ok, "company number input validates"
  extra = good~copy
  extra["url"] = "https://evil.invalid/"
  badUrl = descriptor~validateInput(extra)
  call assertTrue \badUrl~ok, "company API caller cannot supply URL"
  call assertEqual "ABILITY_SCHEMA_ADDITIONAL_PROPERTY", badUrl~code, "company URL injection rejected by schema"
  extraCred = good~copy
  extraCred["credential_reference"] = "another-credential"
  badCred = descriptor~validateInput(extraCred)
  call assertTrue \badCred~ok, "company API caller cannot select credential reference"
  call assertEqual "ABILITY_SCHEMA_ADDITIONAL_PROPERTY", badCred~code, "credential selection remains deployment-owned"

  root = civicTestTempDir("civic_company_contract_v09")
  transport = .CivicTestSequenceTransport~new
  rawHeaders = readBinary("fixtures/companies_house_fixture.headers")
  body = readBinary("fixtures/companies_house_fixture.body")
  ignore = transport~addHttp(200, "OK", rawHeaders, body)
  allow = .CivicAllowList~new
  endpoint = .CivicCompaniesHouseAdapter~endpointTemplate
  ignore = allow~add(endpoint~scheme, endpoint~host, endpoint~pathTemplate, endpoint~allowQuery, endpoint~port)
  client = .CivicClient~new(transport, allow)
  cache = .CivicCache~new(client, .CivicJournal~new(root))
  outcome = cache~get(.CivicCompaniesHouseAdapter~companyUrl("01234567"), .nil, 10, "", .false, "companieshouse-fixture")
  call assertTrue outcome~ok, "company fixture cache fetch succeeds"
  output = contract~projectCacheResult(outcome)
  check = descriptor~validateOutput(output)
  call assertTrue check~ok, "company evidence projection satisfies exact output schema"
  call assertEqual "civic.company.lookup/0.1", output["contract_generation"], "company output carries contract generation"
  call assertEqual "companieshouse.company-profile/0.1", output["mapping_generation"], "company output carries mapping generation"
  call assertEqual "companieshouse-fixture", output["credential_reference"], "company output discloses only non-secret credential reference"
  call assertEqual "01234567", output["values"]["company_number"]~string, "company number projected"
  call assertTrue output["values"]["company_number"]~isA(.JsonString), "numeric-looking company number remains JSON string typed"
  call assertEqual "CIVICPORT FIXTURE LIMITED", output["values"]["company_name"], "company name projected"
  call assertEqual "PRESENT_NULL", output["field_states"]["registered_office_address_line_2"], "explicit null survives company API field state"
  call assertTrue \output["values"]~hasIndex("registered_office_address_line_2"), "null address line does not become a string"
  call assertTrue output["values"]["has_insolvency_history"]~isA(.JsonBoolean), "company boolean output remains JSON boolean"
  call assertTrue \output["values"]["has_insolvency_history"]~value, "company false boolean remains false"
  call assertTrue \output["values"]~hasIndex("sic_codes"), "structured SIC array is not silently flattened into API values"

  pin = contract~profilePin("civic-test-client", "1", "civic", "tests/RuntimeCivicContractFixture_v1.cls", "company-handler-v1")
  call assertEqual "civicport-company", pin~profile~profileId, "company profile has its own pinned profile identity family"
  call assertTrue pin~profile~canonicalText~pos("companieshouse.company-profile/0.1") > 0, "company profile canonical text incorporates mapping generation"

  ignore = civicTestRemoveTree(root)
  return

::requires "TestSupport.cls"
::requires "CacheTestSupport.cls"
::requires "CivicCompaniesHouseRuntime.cls"
