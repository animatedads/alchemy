body = readBinary("../tests/fixtures/companies_house_fixture.body")
rawHeaders = readBinary("../tests/fixtures/companies_house_fixture.headers")

endpoint = .CivicCompaniesHouseAdapter~endpointTemplate
allow = .CivicAllowList~new
ignore = allow~add(endpoint~scheme, endpoint~host, endpoint~pathTemplate, endpoint~allowQuery, endpoint~port)

url = .CivicCompaniesHouseAdapter~companyUrl("01234567")
transport = .CivicFixtureTransport~new
ignore = transport~add(.CivicFixture~new("GET", url, 200, "OK", rawHeaders, body))
client = .CivicClient~new(transport, allow)
fetch = client~get(url, .nil, 10, "", "companieshouse-fixture")
if \fetch~ok then do
  say fetch~errorCode fetch~message
  exit 1
end

doc = fetch~document
mapped = .CivicCompaniesHouseAdapter~new~map(doc)
say doc~string
say "credential reference:" doc~request~credentialRef
say "mapping:" mapped~mappingId mapped~status
if mapped~ok then do
  say "company number:" mapped~row["company_number"]
  say "company name:" mapped~row["company_name"]
  say "status:" mapped~row["company_status"]
  say "registered office locality:" mapped~row["registered_office_locality"]
  say "sic_codes retained as native array:" doc~parsed["sic_codes"]~isA(.Array)
end
exit 0

::routine readBinary
  use arg path
  s=.Stream~new(path); ignore=s~open("READ"); n=s~chars
  if n > 0 then data=s~charin(1,n); else data=""
  ignore=s~close
  return data

::requires "CivicCompaniesHouse.cls"
::requires "CivicClient.cls"
