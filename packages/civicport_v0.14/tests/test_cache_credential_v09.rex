call test_cache_credential_v09
say "PASS test_cache_credential_v09"
exit 0

test_cache_credential_v09:
  url = .CivicCompaniesHouseAdapter~companyUrl("01234567")
  r1 = .CivicRequest~new(url, "GET", .nil, "", 10, "", "companieshouse-a")
  r2 = .CivicRequest~new(url, "GET", .nil, "", 10, "", "companieshouse-b")
  r3 = .CivicRequest~new(url)
  k1 = .CivicCacheKey~forRequest(r1)
  k2 = .CivicCacheKey~forRequest(r2)
  k3 = .CivicCacheKey~forRequest(r3)
  call assertTrue k1 \== k2, "different non-secret credential references have different cache identity"
  call assertTrue k1 \== k3, "credentialized and uncredentialized requests cannot share cache identity"
  call assertTrue k1~pos(c2x("companieshouse-a")) > 0, "cache key incorporates credential reference without secret material"

  root = civicTestTempDir("civicport-v09-credential-journal")
  allow = .CivicAllowList~new
  endpoint = .CivicCompaniesHouseAdapter~endpointTemplate
  ignore = allow~add(endpoint~scheme, endpoint~host, endpoint~pathTemplate)
  transport = .CivicFixtureTransport~new
  headers = readBinary("fixtures/companies_house_fixture.headers")
  body = readBinary("fixtures/companies_house_fixture.body")
  ignore = transport~add(.CivicFixture~new("GET", url, 200, "OK", headers, body))
  client = .CivicClient~new(transport, allow)
  journal = .CivicJournal~new(root)
  cache = .CivicCache~new(client, journal)
  outcome = cache~get(url, .nil, 10, "", .false, "companieshouse-a")
  call assertTrue outcome~ok, "credential-referenced fixture caches"
  call assertEqual "companieshouse-a", outcome~document~request~credentialRef, "credential reference retained in live journal document"

  reloaded = .CivicJournal~new(root)
  record = reloaded~record(outcome~bodyRecordId)
  call assertEqual "companieshouse-a", record~document~request~credentialRef, "credential reference survives journal restart"
  call assertTrue record~cacheKey~pos(c2x("companieshouse-a")) > 0, "reloaded record retains credential-partitioned cache key"
  call civicTestRemoveTree(root)
  return

::requires "TestSupport.cls"
::requires "CacheTestSupport.cls"
::requires "CivicCompaniesHouse.cls"
::requires "CivicCache.cls"
