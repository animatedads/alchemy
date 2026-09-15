call test_relation_company_v077
say "PASS test_relation_company_v077"
exit 0

test_relation_company_v077:
  journalRoot = civicTestTempDir("civic_company_relation")
  dbRoot = civicNoSQLCreateBlankDatabase("civic-company-v077")
  rawHeaders = readBinary("fixtures/companies_house_fixture.headers")
  body = readBinary("fixtures/companies_house_fixture.body")

  allow = .CivicAllowList~new
  endpoint = .CivicCompaniesHouseAdapter~endpointTemplate
  ignore = allow~add(endpoint~scheme, endpoint~host, endpoint~pathTemplate, endpoint~allowQuery, endpoint~port)
  transport = .CivicTestSequenceTransport~new
  ignore = transport~addHttp(200, "OK", rawHeaders, body)
  client = .CivicClient~new(transport, allow)
  journal = .CivicJournal~new(journalRoot)
  cache = .CivicCache~new(client, journal)

  provider = .CivicRelationProvider~new(cache, .DatabaseResult, .TableDefinition)
  definition = provider~defineCompanyRelation("civic_company", "01234567", "companieshouse-fixture")
  fed = .FederatedDatabaseEngine~new(dbRoot)
  ignore = fed~addEngine(provider)

  catalog = fed~readCatalog
  call assertTrue contains(catalog["tables"], "civic_company"), "company relation is discoverable"
  call assertEqual 0, transport~requestCount, "company catalog discovery performs no HTTP"
  meta = fed~tableMetadata("civic_company")
  call assertEqual 27, meta~columns~items, "company relation metadata exposes explicit evidence columns"
  call assertEqual 0, transport~requestCount, "company metadata discovery performs no HTTP"

  bad = fed~execute("UPDATE civic_company SET company_status='dissolved' WHERE company_number='01234567'")
  call assertEqual .Error~SQLUNSUPPORTED, bad~error, "company relation mutation is SQLUNSUPPORTED"
  call assertEqual 0, transport~requestCount, "rejected company mutation does not materialize"

  query = fed~execute("SELECT company_number, company_name, company_status, registered_office_locality, has_insolvency_history, credential_reference, mapping_generation FROM civic_company")
  call assertEqual .Error~SUCCESS, query~status, "company SELECT succeeds"
  call assertEqual 1, query~rows~items, "one company profile row"
  row = query~rows[1]
  call assertEqual "01234567", row["company_number"], "company number projected"
  call assertEqual "CIVICPORT FIXTURE LIMITED", row["company_name"], "company name projected"
  call assertEqual "active", row["company_status"], "company status projected"
  call assertEqual "Cardiff", row["registered_office_locality"], "company office locality projected"
  call assertEqual "FALSE", row["has_insolvency_history"], "JSON boolean has explicit SQL lexical projection"
  call assertEqual "companieshouse-fixture", row["credential_reference"], "non-secret credential reference visible at SQL evidence boundary"
  call assertEqual "companieshouse.company-profile/0.1", row["mapping_generation"], "company mapping generation visible"
  call assertEqual 1, transport~requestCount, "first company SELECT materializes once"
  call assertEqual "companieshouse-fixture", transport~request(1)~credentialRef, "relation passes non-secret credential reference through cache to request"
  call assertTrue \transport~request(1)~headers~has("Authorization"), "relation request still contains no Authorization header"

  rich = provider~table("civic_company")~readRows[1]
  call assertTrue rich~document~parsed["sic_codes"]~isA(.Array), "rich company evidence retains structured SIC array"
  call assertEqual "companieshouse-fixture", rich~document~request~credentialRef, "rich evidence retains credential reference"
  call assertEqual 1, transport~requestCount, "rich rescan reuses frozen materialization"

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
