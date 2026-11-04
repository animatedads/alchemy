/* NoSQLServer v0.88 query execution instrumentation forcing regression. */

identity = .InstrumentationCodec~identity("qualification", "nosqlserver", "v088", "test-node", "", "DATABASE")
metrics = .NoSQLServerInstrumentationSource~new(identity)

root = .NoSQLServerTestSupport~createBlankDatabase("v088-query-instrumentation")
engine = .FileDatabaseEngine~new(root)
engine~instrumentation = metrics
sql = .NoSQLServerSQL~new(engine)

call assertSuccess sql~execute("CREATE TABLE sample (id INTEGER PRIMARY KEY, label VARCHAR(32), population INTEGER)")
call assertSuccess sql~execute("INSERT INTO sample (id,label,population) VALUES (1,'alpha',1411778724),(2,'beta',1013662000)")
queryRs = sql~execute("SELECT id,label,population FROM sample ORDER BY id")
call assertSuccess queryRs
call assert queryRs~rows~items = 2, "query row count"
call assert queryRs~rowsScanned >= 2, "query exposes rows scanned"
call assert queryRs~accessPath <> "", "query exposes access path"

snap = metrics~snapshot("2026-10-09T20:00:00Z")
call assert metricValue(snap, "database.query.rows_returned") = 2, "returned-row distribution"
call assert metricValue(snap, "database.query.rows_scanned") >= 2, "rows-scanned distribution"
call assert metricValue(snap, "database.query.last_rows_scanned") >= 2, "last rows-scanned gauge"
call assert metricValue(snap, "database.query.scan_amplification") >= 1, "scan amplification"
call assert metricValue(snap, "database.query.last_access_path") <> 0, "access path state"
call assert metricDimension(snap, "database.query.duration_seconds", "instrumentation_api") = "instrumentation.mesh/0.1", "semantic instrumentation API dimension"
call assert metricDimension(snap, "database.query.duration_seconds", "operation") = "SELECT", "query operation dimension"
call assert metricDimension(snap, "database.query.last_access_path", "release") = "0.88", "release dimension"

cleanupResult = .NoSQLServerTestSupport~removeDatabase(root)
say "NOSQLSERVER V0.88 QUERY EXECUTION INSTRUMENTATION: PASS"
say "ROWS_RETURNED=" || queryRs~rows~items
say "ROWS_SCANNED=" || queryRs~rowsScanned
say "ACCESS_PATH=" || queryRs~accessPath
exit 0

metricValue: procedure
  use arg snap, metricName
  do sample over snap["samples"]
    if sample["name"] = metricName then return sample["value"]
  end
  return 0

metricDimension: procedure
  use arg snap, metricName, dimensionName
  do sample over snap["samples"]
    if sample["name"] = metricName then do
      dims=sample["dimensions"]
      if dims==.nil then return ""
      value=dims[dimensionName]
      if value==.nil then return ""
      return value
    end
  end
  return ""

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
