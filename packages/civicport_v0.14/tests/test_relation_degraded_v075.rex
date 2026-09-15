call test_relation_degraded_v075
say "PASS test_relation_degraded_v075"
exit 0

test_relation_degraded_v075:
  journalRoot = civicTestTempDir("civic_relation_degraded")
  dbRoot = civicNoSQLCreateBlankDatabase("civic-relation-degraded-v075")
  headers200 = "HTTP/1.1 200 OK" || '0d0a'x || -
    "Content-Type: application/json" || '0d0a'x || -
    'ETag: "relation-degraded-v1"' || '0d0a0d0a'x
  body = '{"status":200,"result":{"postcode":"SW1A 1AA","country":"England","admin_district":"Westminster","region":null,"longitude":-0.141588,"latitude":51.501009,"parliamentary_constituency":"Cities of London and Westminster"}}'
  headers429 = "HTTP/1.1 429 Too Many Requests" || '0d0a'x || -
    "Content-Type: application/json" || '0d0a'x || -
    "Retry-After: 00060" || '0d0a0d0a'x

  allow = .CivicAllowList~new
  endpoint = .CivicPostcodeAdapter~endpointTemplate
  ignore = allow~add(endpoint~scheme, endpoint~host, endpoint~pathTemplate, endpoint~allowQuery, endpoint~port)
  transport = .CivicTestSequenceTransport~new
  ignore = transport~addHttp(200, "OK", headers200, body)
  ignore = transport~addHttp(429, "Too Many Requests", headers429, '{"status":429,"error":"rate limit"}')
  cache = .CivicCache~new(.CivicClient~new(transport, allow), .CivicJournal~new(journalRoot))
  url = "https://api.postcodes.io/postcodes/SW1A%201AA"

  seeded = cache~get(url)
  call assertTrue seeded~ok, "seed 200 cached"
  provider = .CivicRelationProvider~new(cache, .DatabaseResult, .TableDefinition)
  definition = provider~definePostcodeRelation("civic_postcode", url, .nil, .true)
  fed = .FederatedDatabaseEngine~new(dbRoot)
  ignore = fed~addEngine(provider)

  meta = fed~tableMetadata("civic_postcode")
  call assertEqual 20, meta~columns~items, "v0.7 relation exposes access-state columns"
  call assertEqual 1, transport~requestCount, "metadata still performs no new network access"

  query = fed~execute("SELECT postcode, http_status, observation_http_status, access_state, degradation_cause, retry_after, stale_reason_code, degradation_detail, cache_state FROM civic_postcode")
  call assertEqual .Error~SUCCESS, query~status, "degraded stale relation remains readable"
  call assertEqual 1, query~rows~items, "stale body still maps to one row"
  row = query~rows[1]
  call assertEqual "SW1A 1AA", row["postcode"], "entity comes from cached 200 body"
  call assertEqual "200", row["http_status"], "SQL body status is earlier 200"
  call assertEqual "429", row["observation_http_status"], "SQL observation status is latest 429"
  call assertEqual "DEGRADED", row["access_state"], "SQL carries degraded access state"
  call assertEqual "RATE_LIMIT", row["degradation_cause"], "SQL carries rate-limit cause"
  call assertEqual "00060", row["retry_after"], "SQL preserves Retry-After lexical value"
  call assertEqual "HTTP_429", row["stale_reason_code"], "SQL carries stale reason code"
  call assertEqual "Too Many Requests", row["degradation_detail"], "SQL carries reason phrase"
  call assertEqual "STALE", row["cache_state"], "SQL separately carries cache state"
  call assertEqual 2, transport~requestCount, "first data read performs one revalidation request"

  rich = provider~table("civic_postcode")~readRows[1]
  call assertEqual "DEGRADED", rich~accessState~state, "rich row retains native access-state object"
  call assertEqual "RATE_LIMIT", rich~accessState~cause, "rich access cause retained"
  prov = rich~provenance
  call assertEqual "DEGRADED", prov["accessState"], "provenance exposes access state"
  call assertEqual "RATE_LIMIT", prov["degradationCause"], "provenance exposes degradation cause"
  call assertEqual "00060", prov["retryAfter"], "provenance preserves retry header"

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
