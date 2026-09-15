call test_relation_invalid_v074
say "PASS test_relation_invalid_v074"
exit 0

test_relation_invalid_v074:
  journalRoot = civicTestTempDir("civic_relation_bad")
  dbRoot = civicNoSQLCreateBlankDatabase("civic-relation-invalid-v074")
  rawHeaders = "HTTP/1.1 200 OK" || '0d0a'x || "Content-Type: application/json" || '0d0a0d0a'x
  body = '{"status":200,"result":{"country":"England"}}'
  allow = .CivicAllowList~new
  ignore = allow~add("https", "api.postcodes.io", "/postcodes/{postcode}")
  transport = .CivicTestSequenceTransport~new
  ignore = transport~addHttp(200, "OK", rawHeaders, body)
  cache = .CivicCache~new(.CivicClient~new(transport, allow), .CivicJournal~new(journalRoot))
  provider = .CivicRelationProvider~new(cache, .DatabaseResult, .TableDefinition)
  ignore = provider~definePostcodeRelation("civic_postcode", "https://api.postcodes.io/postcodes/BAD")
  fed = .FederatedDatabaseEngine~new(dbRoot)
  ignore = fed~addEngine(provider)

  query = fed~execute("SELECT postcode FROM civic_postcode")
  call assertEqual .Error~NOTEXECUTED, query~status, "schema-invalid civic source does not become a successful empty relation"
  call assertEqual "SQLERROR", query~error, "mapping invalidity surfaces at relation boundary"
  call assertTrue query~message~pos("CIVIC_MAPPING_INVALID") > 0, "mapping invalidity is explicit"
  call assertTrue query~message~pos("SCHEMA_REQUIRED_MISSING") > 0, "required pointer failure retained"
  call assertEqual 0, query~rows~items, "schema-invalid document yields no SQL row"
  call assertEqual 1, transport~requestCount, "invalidity follows one actual materialization attempt"
  call assertEqual 1, cache~journal~count, "invalid HTTP document remains journaled evidence"

  ignore = civicNoSQLRemoveDatabase(dbRoot)
  return civicTestRemoveTree(journalRoot)

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
