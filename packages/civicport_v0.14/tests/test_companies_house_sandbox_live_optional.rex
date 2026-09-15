live = value("CIVICPORT_COMPANIES_HOUSE_SANDBOX_LIVE_TEST",, "ENVIRONMENT")
if live \= "1" then do
  say "SKIP test_companies_house_sandbox_live_optional (set CIVICPORT_COMPANIES_HOUSE_SANDBOX_LIVE_TEST=1)"
  exit 0
end
apiKey = value("COMPANIES_HOUSE_SANDBOX_API_KEY",, "ENVIRONMENT")
if apiKey = "" then do
  say "FAIL test_companies_house_sandbox_live_optional: COMPANIES_HOUSE_SANDBOX_API_KEY is required"
  exit 2
end
companyNumber = value("CIVICPORT_COMPANIES_HOUSE_SANDBOX_COMPANY_NUMBER",, "ENVIRONMENT")
if companyNumber = "" then do
  say "FAIL test_companies_house_sandbox_live_optional: CIVICPORT_COMPANIES_HOUSE_SANDBOX_COMPANY_NUMBER is required"
  exit 2
end

provider = .CivicEnvironmentCredentialProvider~new
ignore = provider~addBasicApiKey(.CivicCompaniesHouseEnvironment~SANDBOX_CREDENTIAL_REFERENCE, "COMPANIES_HOUSE_SANDBOX_API_KEY", .CivicCompaniesHouseEnvironment~SANDBOX_HOST)
allow = .CivicAllowList~new
endpoint = .CivicCompaniesHouseSandboxAdapter~endpointTemplate
ignore = allow~add(endpoint~scheme, endpoint~host, endpoint~pathTemplate, endpoint~allowQuery, endpoint~port)
client = .CivicClient~new(.CivicCurlTransport~new("curl", provider), allow)
url = .CivicCompaniesHouseSandboxAdapter~companyUrl(companyNumber)
fetch = client~get(url, .nil, 20, "", .CivicCompaniesHouseEnvironment~SANDBOX_CREDENTIAL_REFERENCE)
call assertTrue fetch~ok, "sandbox Companies House transport returns an HTTP document"
doc = fetch~document
call assertEqual .CivicCompaniesHouseEnvironment~SANDBOX_CREDENTIAL_REFERENCE, doc~request~credentialRef, "sandbox request retains only sandbox credential reference"
call assertTrue \doc~request~headers~has("Authorization"), "sandbox evidence contains no Authorization secret"
call assertTrue doc~request~url~pos(.CivicCompaniesHouseEnvironment~SANDBOX_HOST) > 0, "sandbox probe cannot silently hit live host"
call assertTrue doc~status >= 100 & doc~status <= 599, "sandbox HTTP status retained"
if doc~status = 200 then do
  mapped = .CivicCompaniesHouseSandboxAdapter~new~map(doc)
  call assertTrue mapped~ok, "sandbox 200 company profile matches pinned mapping"
  call assertEqual "companieshouse.company-profile/0.1", mapped~mappingId, "sandbox mapping generation explicit"
end
say "LIVE Companies House SANDBOX status=" || doc~status || " digest=" || doc~bodyDigest
say "PASS test_companies_house_sandbox_live_optional"
exit 0

::requires "TestSupport.cls"
::requires "CivicCompaniesHouse.cls"
::requires "CivicCredential.cls"
::requires "CivicClient.cls"
