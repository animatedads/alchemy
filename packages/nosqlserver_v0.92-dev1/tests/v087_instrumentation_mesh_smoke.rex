/* NoSQLServer v0.87 Instrumentation Mesh observation forcing regression. */

identity = .InstrumentationCodec~identity("qualification", "nosqlserver", "v087", "test-node", "", "DATABASE")
metrics = .NoSQLServerInstrumentationSource~new(identity)

/* Query timing/events are emitted by the normal SQL executor boundary. */
root = .NoSQLServerTestSupport~createBlankDatabase("v087-instrumentation")
engine = .FileDatabaseEngine~new(root)
engine~instrumentation = metrics
sql = .NoSQLServerSQL~new(engine)
call assertSuccess sql~execute("CREATE TABLE sample (id INTEGER PRIMARY KEY, label VARCHAR(32), population INTEGER)")
call assertSuccess sql~execute("INSERT INTO sample (id,label,population) VALUES (1,'alpha',1411778724),(2,'beta',1013662000)")
queryRs = sql~execute("SELECT id,label,population FROM sample ORDER BY id")
call assertSuccess queryRs
call assert queryRs~instrumentation == metrics, "query result carries instrumentation source"
call assert queryRs~rows~items = 2, "query row count"

/* 1,400-row bulk boundary uses the same observer without changing authority. */
bulkRs = .DatabaseResult~new(.DatabaseOperationType~QUERY)
bulkRs~instrumentation = metrics
do i = 1 to 1400
  vals = .table~new
  raw = .table~new
  types = .table~new
  call putTyped vals, raw, types, "id", i, .DatabaseType~INTEGER
  call putTyped vals, raw, types, "population", "1411778724", .DatabaseType~INTEGER
  call putTyped vals, raw, types, "ratio", "12345.6789", .DatabaseType~DECIMAL
  call putTyped vals, raw, types, "numeric_text", "00123", .DatabaseType~VARCHAR
  call putTyped vals, raw, types, "name", "row-" || i, .DatabaseType~VARCHAR
  call putTyped vals, raw, types, "active", "TRUE", .DatabaseType~BOOLEAN
  call putTyped vals, raw, types, "created_date", "2026-10-08", .DatabaseType~DATE
  call putTyped vals, raw, types, "created_at", "2026-10-08T10:01:00", .DatabaseType~DATETIME
  call putTyped vals, raw, types, "payload", "00FF7E", .DatabaseType~BLOB
  call putTyped vals, raw, types, "shape", "POINT (1 2)", .DatabaseType~GEOMETRY
  vals["nothing"] = .nil
  raw["nothing"] = .nil
  types["nothing"] = .DatabaseType~NULL
  bulkRs~rows~append(.DatabaseRow~new(vals, raw, types))
end

started = time("E")
dirs = bulkRs~asDirectories
directorySeconds = time("E") - started
call assert dirs~items = 1400, "directory materialisation row count"
call assert bulkRs~asDirectories == dirs, "directory materialisation cached"

started = time("E")
jsonText = bulkRs~asJson
jsonSeconds = time("E") - started
call assert jsonText~pos('"population":1411778724') > 0, "INTEGER JSON semantics retained"
call assert jsonText~pos('"numeric_text":"00123"') > 0, "VARCHAR JSON semantics retained"
call assert jsonText~pos('"active":true') > 0, "BOOLEAN JSON semantics retained"
call assert jsonText~pos('"nothing":null') > 0, "NULL JSON semantics retained"
call assert bulkRs~asJson = jsonText, "JSON serialization cached"

snap = metrics~snapshot("2026-10-08T09:01:00Z")
call assert metricValue(snap, "database.query.accepted_total") >= 3, "query accepted events"
call assert metricValue(snap, "database.query.completed_total") >= 3, "query completed events"
call assert metricValue(snap, "database.result.materialisations_total") = 2, "directory and JSON projections observed"
call assert metricValue(snap, "database.result.rows_materialised_total") = 2800, "materialised row observations"
call assert metricValue(snap, "database.result.values_materialised_total") = 30800, "materialised value observations"
call assert metricValue(snap, "database.result.materialise_cache_hits_total") >= 1, "materialisation cache hit observed"
call assert metricValue(snap, "database.result.json_serialisations_total") = 1, "one JSON serialization observed"
call assert metricValue(snap, "database.result.json_cache_hits_total") >= 1, "JSON cache hit observed"
call assert metricValue(snap, "database.result.json_bytes_total") = jsonText~length, "JSON byte count observed"
call assert metricValue(snap, "request.inflight") = 0, "request inflight returns to zero"

cleanupResult = .NoSQLServerTestSupport~removeDatabase(root)
say "NOSQLSERVER V0.87 INSTRUMENTATION MESH: PASS"
say "BULK_ROWS=" || bulkRs~rowCount
say "BULK_DIRECTORY_SECONDS=" || directorySeconds
say "BULK_JSON_SECONDS=" || jsonSeconds
say "BULK_JSON_BYTES=" || jsonText~length
exit 0

metricValue: procedure
  use arg snap, metricName
  do sample over snap["samples"]
    if sample["name"] = metricName then return sample["value"]
  end
  return 0

putTyped: procedure
  use arg vals, raw, types, name, value, typeName
  vals[name] = value
  raw[name] = value
  types[name] = typeName
  return

assertSuccess: procedure
  use arg rs
  if rs~status \= .Error~SUCCESS then do
    say "FAIL expected SUCCESS got" rs~status rs~error rs~message
    exit 1
  end
  return

assert: procedure
  use arg condition, label
  if \condition then do
    say "FAIL" label
    exit 1
  end
  return

::requires "../src/NoSQLServerInstrumentation.cls"
::requires "TestSupport.cls"
