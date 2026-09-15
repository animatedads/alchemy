call test_relation_metar_v077
say "PASS test_relation_metar_v077"
exit 0

test_relation_metar_v077:
  journalRoot = civicTestTempDir("civic_metar_relation")
  dbRoot = civicNoSQLCreateBlankDatabase("civic-metar-v077")
  rawHeaders = readBinary("fixtures/aviationweather_EGLL_fixture.headers")
  body = readBinary("fixtures/aviationweather_EGLL_fixture.body")

  allow = .CivicAllowList~new
  endpoint = .CivicAviationWeatherAdapter~endpointTemplate
  ignore = allow~add(endpoint~scheme, endpoint~host, endpoint~pathTemplate, endpoint~allowQuery, endpoint~port, endpoint~queryTemplate)
  transport = .CivicTestSequenceTransport~new
  ignore = transport~addHttp(200, "OK", rawHeaders, body)
  cache = .CivicCache~new(.CivicClient~new(transport, allow), .CivicJournal~new(journalRoot))

  provider = .CivicRelationProvider~new(cache, .DatabaseResult, .TableDefinition)
  definition = provider~defineMetarRelation("civic_metar", "egll")
  fed = .FederatedDatabaseEngine~new(dbRoot)
  ignore = fed~addEngine(provider)

  catalog = fed~readCatalog
  call assertTrue contains(catalog["tables"], "civic_metar"), "METAR relation is discoverable"
  call assertEqual 0, transport~requestCount, "METAR catalog discovery performs no HTTP"
  meta = fed~tableMetadata("civic_metar")
  call assertEqual 31, meta~columns~items, "METAR metadata exposes explicit scalar/evidence columns"
  call assertEqual 0, transport~requestCount, "METAR metadata discovery performs no HTTP"

  bad = fed~execute("UPDATE civic_metar SET temperature_c='99' WHERE station_icao='EGLL'")
  call assertEqual .Error~SQLUNSUPPORTED, bad~error, "METAR relation mutation is SQLUNSUPPORTED"
  call assertEqual 0, transport~requestCount, "rejected METAR mutation does not materialize"

  query = fed~execute("SELECT station_icao, report_time, metar_type, temperature_c, flight_category, source_pointer, mapping_generation FROM civic_metar")
  call assertEqual .Error~SUCCESS, query~status, "METAR SELECT succeeds"
  call assertEqual 2, query~rows~items, "all source array observations become relation rows"
  first = query~rows[1]
  second = query~rows[2]
  call assertEqual "EGLL", first["station_icao"], "first METAR station projected"
  call assertEqual "2026-08-23T15:20:00.000Z", first["report_time"], "first report time projected"
  call assertEqual "METAR", first["metar_type"], "first report type projected"
  call assertEqual "21.0", first["temperature_c"], "first temperature lexical form preserved"
  call assertEqual "VFR", first["flight_category"], "first flight category projected"
  call assertEqual "/0", first["source_pointer"], "first row retains exact source pointer"
  call assertEqual "aviationweather.metar/0.1", first["mapping_generation"], "METAR mapping generation visible"
  call assertEqual "SPECI", second["metar_type"], "second source item remains separate"
  call assertEqual "/1", second["source_pointer"], "second row retains exact source pointer"
  call assertEqual 1, transport~requestCount, "first METAR SELECT performs one document fetch"
  call assertEqual "CivicPort/0.10", transport~request(1)~headers~first("User-Agent"), "METAR relation sends fixed evidence-bearing custom User-Agent"

  richRows = provider~table("civic_metar")~readRows
  call assertEqual 2, richRows~items, "rich relation exposes two projected rows"
  richFirst = richRows[1]
  call assertEqual "/0", richFirst~mappingResult~sourcePointer, "rich row retains mapping source pointer"
  call assertTrue richFirst~document~parsed[1]["clouds"]~isA(.Array), "rich evidence retains structured cloud array"
  call assertEqual "240", richFirst~document~parsed[1]["wdir"], "rich evidence retains unprojected wind direction"
  call assertEqual "VRB", richRows[2]~document~parsed[2]["wdir"], "union string wind direction remains native evidence"
  call assertEqual 1, transport~requestCount, "rich rescan reuses frozen materialization"

  emptyRoot = civicTestTempDir("civic_metar_relation_204")
  transport204 = .CivicTestSequenceTransport~new
  headers204 = "HTTP/1.1 204 No Content" || '0d0a'x || "Content-Type: application/json" || '0d0a0d0a'x
  ignore = transport204~addHttp(204, "No Content", headers204, "")
  emptyCache = .CivicCache~new(.CivicClient~new(transport204, allow), .CivicJournal~new(emptyRoot))
  emptyProvider = .CivicRelationProvider~new(emptyCache, .DatabaseResult, .TableDefinition)
  ignore = emptyProvider~defineMetarRelation("civic_metar_empty", "EGLL")
  emptyRows = emptyProvider~table("civic_metar_empty")~readRows
  call assertEqual 0, emptyRows~items, "HTTP 204 materializes a truthful zero-row METAR relation"
  call assertEqual "", emptyProvider~lastError, "HTTP 204 zero-row relation is not an error"
  call assertEqual 1, transport204~requestCount, "zero-row relation still records one source observation"

  ignore = civicTestRemoveTree(emptyRoot)
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
