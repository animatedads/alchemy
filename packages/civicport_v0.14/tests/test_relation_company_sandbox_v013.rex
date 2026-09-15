call test_relation_company_sandbox_v013
say "PASS test_relation_company_sandbox_v013"
exit 0

test_relation_company_sandbox_v013:
  journalRoot = civicTestTempDir("civic_company_sandbox_relation")
  dbRoot = civicNoSQLCreateBlankDatabase("civic-company-sandbox-v013")
  rawHeaders = readBinary("fixtures/companies_house_fixture.headers")
  body = readBinary("fixtures/companies_house_fixture.body")

  allow = .CivicAllowList~new
  endpoint = .CivicCompaniesHouseSandboxAdapter~endpointTemplate
  ignore = allow~add(endpoint~scheme, endpoint~host, endpoint~pathTemplate, endpoint~allowQuery, endpoint~port)
  transport = .CivicTestSequenceTransport~new
  ignore = transport~addHttp(200, "OK", rawHeaders, body)
  client = .CivicClient~new(transport, allow)
  cache = .CivicCache~new(client, .CivicJournal~new(journalRoot))

  provider = .CivicRelationProvider~new(cache, .DatabaseResult, .TableDefinition)
  definition = provider~defineCompanySandboxRelation("civic_company_sandbox", "01234567", "companieshouse-sandbox-fixture")
  fed = .FederatedDatabaseEngine~new(dbRoot)
  ignore = fed~addEngine(provider)

  catalog = fed~readCatalog
  call assertTrue contains(catalog["tables"], "civic_company_sandbox"), "sandbox company relation is discoverable"
  call assertEqual 0, transport~requestCount, "sandbox catalog discovery performs no HTTP"
  meta = fed~tableMetadata("civic_company_sandbox")
  call assertEqual 27, meta~columns~items, "sandbox relation exposes same explicit evidence columns"
  call assertEqual 0, transport~requestCount, "sandbox metadata discovery performs no HTTP"

  bad = fed~execute("UPDATE civic_company_sandbox SET company_status='dissolved' WHERE company_number='01234567'")
  call assertEqual .Error~SQLUNSUPPORTED, bad~error, "sandbox company relation mutation is SQLUNSUPPORTED"
  call assertEqual 0, transport~requestCount, "rejected sandbox mutation does not materialize"

  query = fed~execute("SELECT company_number, company_name, credential_reference, mapping_generation FROM civic_company_sandbox")
  call assertEqual .Error~SUCCESS, query~status, "sandbox company SELECT succeeds"
  call assertEqual 1, query~rows~items, "one sandbox company profile row"
  row = query~rows[1]
  call assertEqual "01234567", row["company_number"], "sandbox company number projected"
  call assertEqual "CIVICPORT FIXTURE LIMITED", row["company_name"], "sandbox company name projected"
  call assertEqual "companieshouse-sandbox-fixture", row["credential_reference"], "sandbox relation retains only sandbox credential reference"
  call assertEqual "companieshouse.company-profile/0.1", row["mapping_generation"], "sandbox relation shares response mapping generation"
  call assertEqual 1, transport~requestCount, "first sandbox SELECT materializes once"
  call assertTrue transport~request(1)~url~pos("api-sandbox.company-information.service.gov.uk") > 0, "sandbox relation request cannot hit live host"

  ignore = civicNoSQLRemoveDatabase(dbRoot)
  return civicTestRemoveTree(journalRoot)

contains: procedure
  use arg items, wanted
  do item over items
    if item~caselessEquals(wanted) then return .true
  end
  return .false

civicNoSQLCreateBlankDatabase: procedure
  use arg label
  target = SysTempFileName("/tmp/nosqlserver-" || label || "-??????")
  if SysMkDir(target) \= 0 then raise syntax 93.900 additional("Unable to create test root:" target)
  if SysMkDir(target || "/tables") \= 0 then raise syntax 93.900 additional("Unable to create test tables directory:" target)
  catalogPath = target || "/database.yaml"
  call lineout catalogPath, "name: " || label
  call lineout catalogPath, "formatVersion: 1"
  call lineout catalogPath, "tables: []"
  call lineout catalogPath
  return target

civicNoSQLRemoveDatabase: procedure
  use arg target
  if target = "" then return 0
  call SysFileTree target || "/*", "files.", "FOS"
  do i = 1 to files.0
    call SysFileDelete files.i
  end
  call SysFileTree target || "/*", "dirs.", "DOS"
  do i = dirs.0 to 1 by -1
    call SysRmDir dirs.i
  end
  call SysRmDir target
  return 0

::requires "NoSQLServer.cls"
::requires "TestSupport.cls"
::requires "CacheTestSupport.cls"
::requires "CivicRelation.cls"
