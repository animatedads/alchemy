call test_credentials_v09
say "PASS test_credentials_v09"
exit 0

test_credentials_v09:
  ignore = value("CIVICPORT_TEST_CH_KEY", "fixture-secret-123", "ENVIRONMENT")
  provider = .CivicEnvironmentCredentialProvider~new
  binding = provider~addBasicApiKey("companieshouse-fixture", "CIVICPORT_TEST_CH_KEY", "api.company-information.service.gov.uk")
  call assertEqual "companieshouse-fixture", binding~credentialRef, "credential binding exposes only non-secret reference"
  call assertTrue binding~identity~pos("fixture-secret-123") = 0, "credential binding identity contains no secret"

  allow = .CivicAllowList~new
  chEndpoint = .CivicCompaniesHouseAdapter~endpointTemplate
  ignore = allow~add(chEndpoint~scheme, chEndpoint~host, chEndpoint~pathTemplate)
  ignore = allow~add("https", "api.postcodes.io", "/postcodes/{postcode}")
  transport = .CivicCurlTransport~new("./fixtures/fake_companies_house_curl.sh", provider)
  client = .CivicClient~new(transport, allow)

  /* Transport keeps a sealed provider copy: later widening of caller provider does not take effect. */
  ignore = provider~addBasicApiKey("late-binding", "CIVICPORT_TEST_CH_KEY", "api.company-information.service.gov.uk")

  url = .CivicCompaniesHouseAdapter~companyUrl("01234567")
  fetch = client~get(url, .nil, 5, "", "companieshouse-fixture")
  call assertTrue fetch~ok, "credentialized Companies House GET succeeds through transport-only config"
  doc = fetch~document
  call assertEqual "companieshouse-fixture", doc~request~credentialRef, "non-secret credential reference is retained as request evidence"
  call assertTrue \doc~request~headers~has("Authorization"), "Authorization is not retained in CivicRequest"
  call assertEqual "companieshouse-fixture", doc~provenance["credentialReference"], "provenance retains only credential reference"
  call assertTrue doc~string~pos("fixture-secret-123") = 0, "document presentation contains no credential secret"
  call assertTrue doc~bodyBytes~pos("fixture-secret-123") = 0, "response body contains no injected credential secret"
  call assertTrue doc~rawHeaderBytes~pos("fixture-secret-123") = 0, "response headers contain no injected credential secret"

  missingProvider = .CivicClient~new(.CivicCurlTransport~new("./fixtures/fake_companies_house_curl.sh"), allow)
  missing = missingProvider~get(url, .nil, 5, "", "companieshouse-fixture")
  call assertTrue \missing~ok, "credential reference without provider fails"
  call assertEqual "CREDENTIAL_PROVIDER_MISSING", missing~errorCode, "missing provider is explicit"

  late = client~get(url, .nil, 5, "", "late-binding")
  call assertTrue \late~ok, "transport sealed provider snapshot rejects later-added binding"
  call assertEqual "CREDENTIAL_REFERENCE_UNKNOWN", late~errorCode, "late binding cannot widen live transport credential authority"

  hostMismatch = client~get("https://api.postcodes.io/postcodes/SW1A%201AA", .nil, 5, "", "companieshouse-fixture")
  call assertTrue \hostMismatch~ok, "credential binding cannot be reused on a different allowed host"
  call assertEqual "CREDENTIAL_HOST_MISMATCH", hostMismatch~errorCode, "credential host mismatch is explicit"

  directHeaders = .directory~new
  directHeaders["Authorization"] = "Basic should-never-be-retained"
  direct = client~get(url, directHeaders, 5, "", "companieshouse-fixture")
  call assertTrue \direct~ok, "caller-owned Authorization remains rejected"
  call assertEqual "INVALID_HEADER", direct~errorCode, "direct Authorization rejection remains transport policy"

  /* A missing credential is local policy/config failure, never a stale-cache bypass. */
  cacheRoot = civicTestTempDir("civic_credential_stale_guard")
  cache = .CivicCache~new(client, .CivicJournal~new(cacheRoot))
  first = cache~get(url, .nil, 5, "", .false, "companieshouse-fixture")
  call assertTrue first~ok, "credentialized response can populate cache"
  ignore = value("CIVICPORT_TEST_CH_KEY", "", "ENVIRONMENT")
  deniedStale = cache~get(url, .nil, 5, "", .true, "companieshouse-fixture")
  call assertTrue \deniedStale~ok, "credential failure cannot be converted into stale success"
  call assertEqual "CREDENTIAL_SECRET_UNAVAILABLE", deniedStale~errorCode, "missing credential remains explicit even when stale is allowed"
  access = deniedStale~accessState
  call assertEqual "BLOCKED", access~state, "credential failure is blocked local policy state"
  call assertEqual "LOCAL_POLICY", access~cause, "credential failure is not mislabeled transport outage"
  ignore = civicTestRemoveTree(cacheRoot)
  return

::requires "TestSupport.cls"
::requires "CacheTestSupport.cls"
::requires "CivicCache.cls"
::requires "CivicCompaniesHouse.cls"
::requires "CivicClient.cls"
::requires "CivicCredential.cls"
