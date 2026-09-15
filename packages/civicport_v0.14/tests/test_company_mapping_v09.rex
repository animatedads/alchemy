call test_company_mapping_v09
say "PASS test_company_mapping_v09"
exit 0

test_company_mapping_v09:
  url = .CivicCompaniesHouseAdapter~companyUrl("01234567")
  allow = .CivicAllowList~new
  endpoint = .CivicCompaniesHouseAdapter~endpointTemplate
  ignore = allow~add(endpoint~scheme, endpoint~host, endpoint~pathTemplate)
  transport = .CivicFixtureTransport~new
  headers = readBinary("fixtures/companies_house_fixture.headers")
  body = readBinary("fixtures/companies_house_fixture.body")
  ignore = transport~add(.CivicFixture~new("GET", url, 200, "OK", headers, body))
  client = .CivicClient~new(transport, allow)
  fetch = client~get(url, .nil, 5, "", "companieshouse-fixture")
  call assertTrue fetch~ok, "fixture Companies House document materializes"
  doc = fetch~document
  mapped = .CivicCompaniesHouseAdapter~new~map(doc)
  call assertTrue mapped~ok, "Companies House company profile shape maps"
  call assertEqual "companieshouse.company-profile/0.1", mapped~mappingId, "company mapping generation is exact"
  call assertEqual "01234567", mapped~row["company_number"]~string, "company number maps"
  call assertEqual "CIVICPORT FIXTURE LIMITED", mapped~row["company_name"]~string, "company name maps"
  call assertEqual "active", mapped~row["company_status"]~string, "company status maps"
  call assertEqual "Cardiff", mapped~row["registered_office_locality"]~string, "nested office locality maps"
  call assertTrue mapped~row["registered_office_address_line_2"] == .nil, "explicit null remains null in mapped row"
  call assertTrue mapped~row["has_insolvency_history"]~isA(.JsonBoolean), "boolean remains JSON boolean"
  call assertTrue \mapped~row["has_insolvency_history"]~value, "false boolean remains false"
  tree = doc~parsed
  call assertTrue tree["sic_codes"]~isA(.Array), "unprojected SIC codes remain structured in native document"
  call assertEqual 2, tree["sic_codes"]~items, "structured SIC evidence is preserved without flattening"

  badBody = '{"company_name":"NO NUMBER LTD","company_status":"active"}'
  badHeaders = 'HTTP/1.1 200 OK' || '0d0a'x || 'Content-Type: application/json' || '0d0a0d0a'x
  badTransport = .CivicFixtureTransport~new
  ignore = badTransport~add(.CivicFixture~new("GET", url, 200, "OK", badHeaders, badBody))
  badClient = .CivicClient~new(badTransport, allow)
  badFetch = badClient~get(url)
  badMapped = .CivicCompaniesHouseAdapter~new~map(badFetch~document)
  call assertTrue \badMapped~ok, "valid JSON missing required company number is mapping INVALID"
  call assertEqual "SCHEMA_REQUIRED_MISSING", badMapped~errorCode, "company schema mismatch does not invent a row"
  return

::requires "TestSupport.cls"
::requires "CivicCompaniesHouse.cls"
::requires "CivicClient.cls"
