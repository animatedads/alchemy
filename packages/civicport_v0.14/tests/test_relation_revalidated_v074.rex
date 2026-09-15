call test_relation_revalidated_v074
say "PASS test_relation_revalidated_v074"
exit 0

test_relation_revalidated_v074:
  journalRoot = civicTestTempDir("civic_relation_304")
  dbRoot = civicNoSQLCreateBlankDatabase("civic-relation-304-v074")
  body = readBinary("fixtures/postcodes_io_SW1A1AA.body")
  headers200 = readBinary("fixtures/postcodes_io_SW1A1AA.headers")
  headers304 = "HTTP/1.1 304 Not Modified" || '0d0a'x || -
    'ETag: "civicport-v01-fixture"' || '0d0a'x || -
    "Date: Sat, 22 Aug 2026 00:30:00 GMT" || '0d0a0d0a'x
  url = "https://api.postcodes.io/postcodes/SW1A%201AA"
  allow = .CivicAllowList~new
  ignore = allow~add("https", "api.postcodes.io", "/postcodes/{postcode}")
  transport = .CivicTestSequenceTransport~new
  ignore = transport~addHttp(200, "OK", headers200, body)
  ignore = transport~addHttp(304, "Not Modified", headers304, "")
  cache = .CivicCache~new(.CivicClient~new(transport, allow), .CivicJournal~new(journalRoot))

  initial = cache~get(url)
  call assertTrue initial~ok, "initial body enters cache"
  originalFetchedAt = initial~document~fetchedAt
  originalDigest = initial~document~bodyDigest
  originalBodyRecord = initial~bodyRecordId

  provider = .CivicRelationProvider~new(cache, .DatabaseResult, .TableDefinition)
  ignore = provider~definePostcodeRelation("civic_postcode", url)
  fed = .FederatedDatabaseEngine~new(dbRoot)
  ignore = fed~addEngine(provider)
  call assertEqual 1, transport~requestCount, "relation registration does not revalidate"
  ignoreCatalog = fed~readCatalog
  call assertEqual 1, transport~requestCount, "catalog remains network-free with warm cache"

  query = fed~execute("SELECT postcode, http_status, observation_http_status, access_state, degradation_cause, fetched_at, cache_state, body_digest, body_record_id, observation_record_id FROM civic_postcode")
  call assertEqual .Error~SUCCESS, query~status, "revalidated Civic SELECT succeeds"
  row = query~rows[1]
  call assertEqual "200", row["http_status"], "revalidated SQL row still projects body-bearing 200"
  call assertEqual "304", row["observation_http_status"], "revalidated SQL row exposes latest 304 separately"
  call assertEqual "HEALTHY", row["access_state"], "304 revalidation is healthy access, not degradation"
  call assertEqual "NONE", row["degradation_cause"], "304 carries no degradation cause"
  call assertEqual "REVALIDATED", row["cache_state"], "SQL row labels revalidated cache resolution"
  call assertEqual originalFetchedAt, row["fetched_at"], "SQL fetched_at remains body document fetch time"
  call assertEqual originalDigest, row["body_digest"], "SQL digest remains earlier body identity"
  call assertEqual originalBodyRecord, row["body_record_id"], "body record remains earlier 200"
  call assertTrue row["observation_record_id"] \= originalBodyRecord, "304 observation has a distinct journal id"
  call assertEqual 2, transport~requestCount, "first relation read performs one conditional revalidation"

  rich = provider~table("civic_postcode")~readRows[1]
  call assertEqual 200, rich~document~status, "rich row document is body-bearing 200"
  call assertEqual 304, rich~observation~status, "rich row separately retains actual 304 observation"
  call assertEqual "HEALTHY", rich~accessState~state, "rich revalidation access state remains healthy"
  call assertEqual "304", rich~accessState~observationStatus, "rich access state retains 304 observation status"
  call assertEqual originalBodyRecord, rich~cacheResult~bodyRecordId, "cache resolution keeps body link"
  call assertEqual row["observation_record_id"], rich~cacheResult~observationRecordId, "SQL observation id traces to cache result"
  call assertEqual 2, cache~journal~count, "200 and 304 remain separate evidence records"

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
