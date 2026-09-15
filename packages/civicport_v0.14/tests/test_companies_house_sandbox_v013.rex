call test_companies_house_sandbox_v013
say "PASS test_companies_house_sandbox_v013"
exit 0

test_companies_house_sandbox_v013:
  ignore = value("CIVICPORT_TEST_CH_LIVE_KEY", "live-fixture-secret", "ENVIRONMENT")
  ignore = value("CIVICPORT_TEST_CH_SANDBOX_KEY", "sandbox-fixture-secret", "ENVIRONMENT")

  provider = .CivicEnvironmentCredentialProvider~new
  ignore = provider~addBasicApiKey(.CivicCompaniesHouseEnvironment~LIVE_CREDENTIAL_REFERENCE, "CIVICPORT_TEST_CH_LIVE_KEY", .CivicCompaniesHouseEnvironment~LIVE_HOST)
  ignore = provider~addBasicApiKey(.CivicCompaniesHouseEnvironment~SANDBOX_CREDENTIAL_REFERENCE, "CIVICPORT_TEST_CH_SANDBOX_KEY", .CivicCompaniesHouseEnvironment~SANDBOX_HOST)

  liveEndpoint = .CivicCompaniesHouseAdapter~endpointTemplate
  sandboxEndpoint = .CivicCompaniesHouseSandboxAdapter~endpointTemplate
  call assertEqual "api.company-information.service.gov.uk", liveEndpoint~host, "live Companies House host remains pinned"
  call assertEqual "api-sandbox.company-information.service.gov.uk", sandboxEndpoint~host, "sandbox Companies House host is separately pinned"
  call assertTrue liveEndpoint~host \== sandboxEndpoint~host, "live and sandbox are distinct endpoint identities"

  allow = .CivicAllowList~new
  ignore = allow~add(liveEndpoint~scheme, liveEndpoint~host, liveEndpoint~pathTemplate)
  ignore = allow~add(sandboxEndpoint~scheme, sandboxEndpoint~host, sandboxEndpoint~pathTemplate)
  transport = .CivicCurlTransport~new("./fixtures/fake_companies_house_sandbox_curl.sh", provider)
  client = .CivicClient~new(transport, allow)

  sandboxUrl = .CivicCompaniesHouseSandboxAdapter~companyUrl("01234567")
  sandboxFetch = client~get(sandboxUrl, .nil, 5, "", .CivicCompaniesHouseEnvironment~SANDBOX_CREDENTIAL_REFERENCE)
  call assertTrue sandboxFetch~ok, "sandbox credential succeeds only on sandbox endpoint"
  call assertEqual sandboxUrl, sandboxFetch~document~request~url, "sandbox URL retained exactly"
  call assertEqual .CivicCompaniesHouseEnvironment~SANDBOX_CREDENTIAL_REFERENCE, sandboxFetch~document~request~credentialRef, "sandbox request retains only sandbox credential reference"
  call assertTrue \sandboxFetch~document~request~headers~has("Authorization"), "sandbox evidence contains no Authorization header"
  call assertTrue sandboxFetch~document~string~pos("sandbox-fixture-secret") = 0, "sandbox secret absent from document presentation"

  wrongLiveRef = client~get(sandboxUrl, .nil, 5, "", .CivicCompaniesHouseEnvironment~LIVE_CREDENTIAL_REFERENCE)
  call assertTrue \wrongLiveRef~ok, "live credential reference cannot authorize sandbox host"
  call assertEqual "CREDENTIAL_HOST_MISMATCH", wrongLiveRef~errorCode, "live->sandbox credential crossing fails before HTTP"

  liveUrl = .CivicCompaniesHouseAdapter~companyUrl("01234567")
  wrongSandboxRef = client~get(liveUrl, .nil, 5, "", .CivicCompaniesHouseEnvironment~SANDBOX_CREDENTIAL_REFERENCE)
  call assertTrue \wrongSandboxRef~ok, "sandbox credential reference cannot authorize live host"
  call assertEqual "CREDENTIAL_HOST_MISMATCH", wrongSandboxRef~errorCode, "sandbox->live credential crossing fails before HTTP"

  liveRequest = .CivicRequest~new(liveUrl, "GET", .nil, "2026-08-25T08:00:00Z", 5, "", .CivicCompaniesHouseEnvironment~LIVE_CREDENTIAL_REFERENCE)
  sandboxRequest = .CivicRequest~new(sandboxUrl, "GET", .nil, "2026-08-25T08:00:00Z", 5, "", .CivicCompaniesHouseEnvironment~SANDBOX_CREDENTIAL_REFERENCE)
  call assertTrue .CivicCacheKey~forRequest(liveRequest) \== .CivicCacheKey~forRequest(sandboxRequest), "live and sandbox cache identities cannot collide"

  mapped = .CivicCompaniesHouseSandboxAdapter~new~map(sandboxFetch~document)
  call assertTrue mapped~ok, "sandbox response uses same explicit company-profile shape mapping"
  call assertEqual "companieshouse.company-profile/0.1", mapped~mappingId, "sandbox shares response mapping generation without sharing endpoint authority"

  ignore = value("CIVICPORT_TEST_CH_LIVE_KEY", "", "ENVIRONMENT")
  ignore = value("CIVICPORT_TEST_CH_SANDBOX_KEY", "", "ENVIRONMENT")
  return

::requires "TestSupport.cls"
::requires "CivicCache.cls"
::requires "CivicCompaniesHouse.cls"
::requires "CivicCredential.cls"
::requires "CivicClient.cls"
