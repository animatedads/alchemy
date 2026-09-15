live = value("CIVICPORT_COMPANIES_HOUSE_LIVE_TEST",, "ENVIRONMENT")
if live \= "1" then do
  say "SKIP test_companies_house_live_optional (set CIVICPORT_COMPANIES_HOUSE_LIVE_TEST=1)"
  exit 0
end
apiKey = value("COMPANIES_HOUSE_API_KEY",, "ENVIRONMENT")
if apiKey = "" then do
  say "FAIL test_companies_house_live_optional: COMPANIES_HOUSE_API_KEY is required when live test is enabled"
  exit 2
end
companyNumber = value("CIVICPORT_COMPANY_NUMBER",, "ENVIRONMENT")
if companyNumber = "" then companyNumber = "00000006"
provider = .CivicEnvironmentCredentialProvider~new
ignore = provider~addBasicApiKey("companieshouse-live", "COMPANIES_HOUSE_API_KEY", "api.company-information.service.gov.uk")
allow = .CivicAllowList~new
endpoint = .CivicCompaniesHouseAdapter~endpointTemplate
ignore = allow~add(endpoint~scheme, endpoint~host, endpoint~pathTemplate, endpoint~allowQuery, endpoint~port)
client = .CivicClient~new(.CivicCurlTransport~new("curl", provider), allow)
url = .CivicCompaniesHouseAdapter~companyUrl(companyNumber)
fetch = client~get(url, .nil, 20, "", "companieshouse-live")
call assertTrue fetch~ok, "live Companies House transport returns an HTTP document"
doc = fetch~document
call assertEqual "companieshouse-live", doc~request~credentialRef, "live request retains only non-secret credential reference"
call assertTrue \doc~request~headers~has("Authorization"), "live request evidence contains no Authorization secret"
call assertTrue doc~status >= 100 & doc~status <= 599, "live HTTP status is retained"
call assertTrue doc~bodyDigest~length = 128, "live response has SHA-512 digest"
if doc~status = 200 then do
  mapped = .CivicCompaniesHouseAdapter~new~map(doc)
  call assertTrue mapped~ok, "live 200 company profile matches pinned mapping generation"
  call assertEqual "companieshouse.company-profile/0.1", mapped~mappingId, "live mapping generation is explicit"
end
say "LIVE Companies House status=" || doc~status || " digest=" || doc~bodyDigest
say "PASS test_companies_house_live_optional"
exit 0

::requires "TestSupport.cls"
::requires "CivicCompaniesHouse.cls"
::requires "CivicCredential.cls"
::requires "CivicClient.cls"
