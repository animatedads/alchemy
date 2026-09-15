call test_relation_nosql_v074
say "PASS test_relation_nosql_v074"
exit 0

test_relation_nosql_v074:
  journalRoot = civicTestTempDir("civic_relation")
  dbRoot = civicNoSQLCreateBlankDatabase("civic-relation-v074")
  rawHeaders = "HTTP/1.1 200 OK" || '0d0a'x || -
    "Content-Type: application/json" || '0d0a'x || -
    'ETag: "relation-fixture-v1"' || '0d0a0d0a'x
  body = '{"status":200,"result":{"postcode":"SW1A 1AA","country":"England","admin_district":"Westminster","region":null,"longitude":-0.141588,"latitude":51.501009,"parliamentary_constituency":"Cities of London and Westminster"}}'

  allow = .CivicAllowList~new
  endpoint = .CivicPostcodeAdapter~endpointTemplate
  ignore = allow~add(endpoint~scheme, endpoint~host, endpoint~pathTemplate, endpoint~allowQuery, endpoint~port)
  transport = .CivicTestSequenceTransport~new
  ignore = transport~addHttp(200, "OK", rawHeaders, body)
  client = .CivicClient~new(transport, allow)
  journal = .CivicJournal~new(journalRoot)
  cache = .CivicCache~new(client, journal)

  provider = .CivicRelationProvider~new(cache, .DatabaseResult, .TableDefinition)
  definition = provider~definePostcodeRelation("civic_postcode", "https://api.postcodes.io/postcodes/SW1A%201AA")
  fed = .FederatedDatabaseEngine~new(dbRoot)
  ignore = fed~addEngine(provider)

  /* Catalog, metadata, row-count planning, and rejected mutation are observational. */
  catalog = fed~readCatalog
  call assertTrue contains(catalog["tables"], "civic_postcode"), "Civic table is discoverable"
  call assertEqual 0, transport~requestCount, "catalog discovery does not hit transport"
  meta = fed~tableMetadata("civic_postcode")
  call assertTrue meta \== .nil, "provider-neutral metadata exists"
  call assertEqual 20, meta~columns~items, "Civic relation metadata exposes explicit v0.7 columns"
  call assertEqual 0, transport~requestCount, "metadata discovery does not hit transport"
  countBefore = fed~tableRowCount("civic_postcode")
  call assertTrue countBefore == .nil, "unmaterialized row count is unknown"
  call assertEqual 0, transport~requestCount, "row-count planning does not materialize"

  bad = fed~execute("UPDATE civic_postcode SET country='X' WHERE postcode='SW1A 1AA'")
  call assertEqual .Error~SQLUNSUPPORTED, bad~error, "Civic relation mutation is SQLUNSUPPORTED"
  call assertEqual 0, transport~requestCount, "rejected mutation does not materialize"

  query = fed~execute("SELECT postcode, country, longitude, latitude, fetched_at, cache_state, body_digest, body_record_id, observation_record_id, mapping_generation FROM civic_postcode WHERE postcode='SW1A 1AA'")
  call assertEqual .Error~SUCCESS, query~status, "Civic SELECT succeeds"
  call assertEqual 1, query~rows~items, "one projected postcode row"
  row = query~rows[1]
  call assertEqual "SW1A 1AA", row["postcode"], "postcode projected"
  call assertEqual "England", row["country"], "country projected"
  call assertEqual "-0.141588", row["longitude"], "JSON numeric lexical value remains text at SQL boundary"
  call assertEqual "51.501009", row["latitude"], "latitude lexical value retained"
  call assertEqual "MISS", row["cache_state"], "first materialization identifies cache miss"
  call assertEqual "postcodes.io.postcode/0.2", row["mapping_generation"], "mapping generation visible"
  call assertTrue row["fetched_at"]~length > 0, "fetched_at visible"
  call assertEqual 128, row["body_digest"]~length, "SHA-512 digest visible"
  call assertTrue row["body_record_id"]~startsWith("CIVICDOC"), "body journal record visible"
  call assertEqual row["body_record_id"], row["observation_record_id"], "initial 200 is both body and observation"
  call assertEqual "CIVIC_EVIDENCE_MATERIALIZED_SCAN", query~accessPath, "Civic access path explicit"
  call assertEqual 1, transport~requestCount, "first data read materializes exactly once"

  second = fed~execute("SELECT postcode FROM civic_postcode")
  call assertEqual .Error~SUCCESS, second~status, "second SELECT succeeds"
  call assertEqual 1, transport~requestCount, "rescan reuses frozen materialization"
  call assertEqual 1, fed~tableRowCount("civic_postcode"), "row count becomes known after materialization"

  richRows = provider~table("civic_postcode")~readRows
  call assertEqual 1, richRows~items, "direct provider retains rich projected row"
  rich = richRows[1]
  call assertTrue rich~document~isA(.CivicDocument), "row retains native CivicDocument"
  call assertTrue rich~sourceFor("postcode") == rich~document, "cell source resolves to native evidence document"
  call assertEqual rich["body_digest"], rich~document~bodyDigest, "SQL digest traces to native document"
  call assertEqual "postcodes.io.postcode/0.2", rich~mappingResult~mappingId, "rich row retains mapping result"
  prov = rich~provenance
  call assertEqual rich["body_record_id"], prov["bodyRecordId"], "rich provenance retains journal identity"

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
