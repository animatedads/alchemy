catalog = .CivicSourceCatalog~defaultCatalog
call assertEqual 4, catalog~descriptors~items, "default catalogue has four pinned source generations including Companies House sandbox"

post = catalog~resolveExact("postcodes.io.postcode", "postcodes.io.postcode/0.2")
call assertTrue post~ok, "postcode exact generation resolves"
call assertEqual "CIVIC_POSTCODE", post~descriptor~semanticKind, "postcode semantic kind"
call assertEqual "SINGULAR", post~descriptor~projectionKind, "postcode projection kind"
call assertEqual "NONE", post~descriptor~credentialPolicy, "postcode credential policy"
call assertEqual "api.postcodes.io", post~descriptor~host, "postcode host pinned"
call assertEqual "/postcodes/{postcode}", post~descriptor~pathTemplate, "postcode path template pinned"
call assertEqual "civic.postcode.lookup/0.1", post~descriptor~contractGeneration, "postcode Runtime contract generation pinned"

company = catalog~resolveExact("companieshouse.company-profile", "companieshouse.company-profile/0.1")
call assertTrue company~ok, "company exact generation resolves"
call assertEqual "REFERENCE_REQUIRED", company~descriptor~credentialPolicy, "company credential requirement is metadata, not a secret"
call assertEqual "api.company-information.service.gov.uk", company~descriptor~host, "company host pinned"


sandboxCompany = catalog~resolveExact("companieshouse.company-profile.sandbox", "companieshouse.company-profile/0.1")
call assertTrue sandboxCompany~ok, "sandbox company exact generation resolves"
call assertEqual "REFERENCE_REQUIRED", sandboxCompany~descriptor~credentialPolicy, "sandbox company credential requirement is metadata, not a secret"
call assertEqual "api-sandbox.company-information.service.gov.uk", sandboxCompany~descriptor~host, "sandbox company host pinned separately"
call assertEqual "civic.company.lookup.sandbox/0.1", sandboxCompany~descriptor~contractGeneration, "sandbox company Runtime contract generation is distinct"


metar = catalog~resolveExact("aviationweather.metar", "aviationweather.metar/0.1")
call assertTrue metar~ok, "METAR exact generation resolves"
call assertEqual "COLLECTION", metar~descriptor~projectionKind, "METAR collection shape is explicit"
call assertEqual "ids={station}&format=json", metar~descriptor~queryTemplate, "METAR query contract pinned"
call assertEqual "CivicPort/0.10", metar~descriptor~requestHeaders["User-Agent"], "evidence-bearing METAR User-Agent is part of source descriptor"
headerCopy = metar~descriptor~requestHeaders
headerCopy["User-Agent"] = "mutated"
call assertEqual "CivicPort/0.10", metar~descriptor~requestHeaders["User-Agent"], "caller cannot mutate fixed request-header snapshot"
call assertEqual 0, post~descriptor~requestHeaders~items, "postcode descriptor has no hidden fixed request headers"
call assertEqual 0, company~descriptor~requestHeaders~items, "company descriptor carries credential policy, not Authorization material"

credentialHeaderRejected = .false
signal on syntax name credentialHeaderRefused
badHeader = .CivicSourceHeader~new("Authorization", "secret")
signal off syntax
call assertTrue .false, "catalogue fixed headers must not carry credentials"
credentialHeaderRefused:
signal off syntax
credentialHeaderRejected = .true
call assertTrue credentialHeaderRejected, "credential-bearing source header rejected"

badLatest = catalog~negotiate("postcodes.io.postcode", .array~of("latest"))
call assertTrue \badLatest~ok, "latest is never an implicit generation"
call assertEqual "GENERATION_TOKEN_INVALID", badLatest~errorCode, "latest refusal is explicit"
badWildcard = catalog~negotiate("postcodes.io.postcode", .array~of("postcodes.io.postcode/*"))
call assertTrue \badWildcard~ok, "wildcard generation refused"
call assertEqual "GENERATION_TOKEN_INVALID", badWildcard~errorCode, "wildcard refusal is explicit"
unknown = catalog~resolveExact("civic.unknown", "civic.unknown/0.1")
call assertTrue \unknown~ok, "unknown source does not infer an adapter"
call assertEqual "SOURCE_UNKNOWN", unknown~errorCode, "unknown source code"

ability = catalog~resolveAbility("civic.metar.lookup", "civic.metar.lookup/0.1")
call assertTrue ability~ok, "Runtime ability generation resolves back to source descriptor"
call assertEqual "aviationweather.metar", ability~descriptor~sourceId, "ability/source linkage is explicit"

/* Returned descriptor arrays are defensive. */
copy = catalog~descriptors
copy~append(post~descriptor)
call assertEqual 4, catalog~descriptors~items, "caller mutation cannot widen catalog snapshot"

/* Generic selection maps singular sources as one-item collections. */
postSelectionResult = catalog~select("postcodes.io.postcode", .array~of("future-postcode/9", "postcodes.io.postcode/0.2"))
call assertTrue postSelectionResult~ok, "caller ordered acceptable generations select first available exact generation"
postSelection = postSelectionResult~selection
call assertEqual "postcodes.io.postcode/0.2", postSelection~descriptor~mappingGeneration, "selected descriptor pins mapping generation"
allow = .CivicAllowList~new
endpoint = postSelection~endpointTemplate
ignore = allow~add(endpoint~scheme, endpoint~host, endpoint~pathTemplate, endpoint~allowQuery, endpoint~port, endpoint~queryTemplate)
transport = .CivicTestSequenceTransport~new
ignore = transport~addHttp(200, "OK", readBinary("fixtures/postcodes_io_SW1A1AA.headers"), readBinary("fixtures/postcodes_io_SW1A1AA.body"))
fetch = .CivicClient~new(transport, allow)~get("https://api.postcodes.io/postcodes/SW1A%201AA")
postCollection = postSelection~mapAll(fetch~document)
call assertTrue postCollection~ok, "selected postcode adapter maps supplied document"
call assertEqual 1, postCollection~items~items, "singular mapping is presented as one-item generic collection"
call assertEqual "SW1A 1AA", postCollection~items[1]~row["postcode"], "generic selected mapping retains postcode value"
call assertEqual 1, transport~requestCount, "catalogue selection itself performs no network request"

/* Company profile uses the same generic singular mapping surface without resolving credentials. */
companySelectionResult = catalog~select("companieshouse.company-profile", .array~of("companieshouse.company-profile/0.1"))
call assertTrue companySelectionResult~ok, "Companies House adapter selects"
companyEndpoint = companySelectionResult~selection~endpointTemplate
companyAllow = .CivicAllowList~new
ignore = companyAllow~add(companyEndpoint~scheme, companyEndpoint~host, companyEndpoint~pathTemplate, companyEndpoint~allowQuery, companyEndpoint~port, companyEndpoint~queryTemplate)
companyTransport = .CivicTestSequenceTransport~new
ignore = companyTransport~addHttp(200, "OK", readBinary("fixtures/companies_house_fixture.headers"), readBinary("fixtures/companies_house_fixture.body"))
companyFetch = .CivicClient~new(companyTransport, companyAllow)~get(.CivicCompaniesHouseAdapter~companyUrl("01234567"))
companyCollection = companySelectionResult~selection~mapAll(companyFetch~document)
call assertTrue companyCollection~ok, "selected company adapter maps supplied document"
call assertEqual 1, companyCollection~items~items, "company singular mapping is one generic item"
call assertEqual "01234567", companyCollection~items[1]~row["company_number"]~string, "generic selected mapping preserves company number lexical string"

/* METAR selection preserves genuine source multiplicity. */
metarSelectionResult = catalog~select("aviationweather.metar", .array~of("aviationweather.metar/0.1"))
call assertTrue metarSelectionResult~ok, "METAR adapter selects"
metarEndpoint = metarSelectionResult~selection~endpointTemplate
metarAllow = .CivicAllowList~new
ignore = metarAllow~add(metarEndpoint~scheme, metarEndpoint~host, metarEndpoint~pathTemplate, metarEndpoint~allowQuery, metarEndpoint~port, metarEndpoint~queryTemplate)
metarTransport = .CivicTestSequenceTransport~new
ignore = metarTransport~addHttp(200, "OK", readBinary("fixtures/aviationweather_EGLL_fixture.headers"), readBinary("fixtures/aviationweather_EGLL_fixture.body"))
metarFetch = .CivicClient~new(metarTransport, metarAllow)~get(.CivicAviationWeatherAdapter~metarUrl("EGLL"), metarSelectionResult~selection~requestHeaders)
metarCollection = metarSelectionResult~selection~mapAll(metarFetch~document)
call assertTrue metarCollection~ok, "selected METAR adapter maps supplied collection document"
call assertEqual 2, metarCollection~items~items, "generic selection does not collapse source array"
call assertEqual "/1", metarCollection~items[2]~sourcePointer, "source pointer survives generic selection"

say "PASS test_catalog_v011"
exit 0

::requires "TestSupport.cls"
::requires "CacheTestSupport.cls"
::requires "CivicCatalog.cls"
