sourceRoot = arg(1)
if sourceRoot = "" then do
  say "usage: smoke.rex DATABASE_ROOT"
  exit 2
end

root = .NoSQLServerTestSupport~cloneDatabase(sourceRoot, "smoke")

db = .FileDatabaseEngine~new(root)

customer = db~table("customer")
call assert customer \== .nil, "customer table opens"
call assert customer~definition~delimiterDefinition~display = ",", "customer comma delimiter"

events = db~table("event_log")
call assert events \== .nil, "event table opens"
call assert events~definition~delimiterDefinition~display = "TAB", "event TAB delimiter"

telemetry = db~table("telemetry")
call assert telemetry \== .nil, "telemetry table opens"
call assert telemetry~definition~delimiterDefinition~display = "HEX:FE", "telemetry FE delimiter"
call assert c2x(telemetry~definition~delimiterDefinition~resolved) = "FE", "telemetry resolves x2c(FE)"

r = .table~new
r["customer_id"] = "1"
r["name"] = "Fred Bloggs"
r["email"] = "fred@example.com"
rs = db~insert("customer", r)
call assert rs~status = .Error~SUCCESS, "insert succeeds"
call assert rs~affectedRows = 1, "insert affects one"

r = .table~new
r["customer_id"] = "2"
r["name"] = "Jane Smith"
r["email"] = "jane@example.com"
rs = db~insert("customer", r)
call assert rs~affectedRows = 1, "second insert"

rs = db~selectWhereEquals("customer", "customer_id", "2")
call assert rs~rows~items = 1, "where returns one"
call assert rs~rows[1]["name"] = "Jane Smith", "where row correct"

chg = .table~new
chg["name"] = "Jane Doe"
rs = db~updateWhereEquals("customer", "customer_id", "2", chg)
call assert rs~affectedRows = 1, "update one"
rs = db~selectWhereEquals("customer", "customer_id", "2")
call assert rs~rows[1]["name"] = "Jane Doe", "updated value persisted"

rs = db~deleteWhereEquals("customer", "customer_id", "1")
call assert rs~affectedRows = 1, "delete one"
rs = db~selectAll("customer")
call assert rs~rows~items = 1, "one customer remains"

te = .table~new
te["sensor_id"] = "73"
te["reading"] = "18.5"
rs = db~insert("telemetry", te)
call assert rs~affectedRows = 1, "FE table insert"
rs = db~selectWhereEquals("telemetry", "sensor_id", "73")
call assert rs~rows~items = 1, "FE table read"
call assert rs~rows[1]["reading"] = "18.5", "FE table value"

cleanupResult = .NoSQLServerTestSupport~removeDatabase(root)
say "NOSQLSERVER NATIVE STORAGE SMOKE: OK"
exit 0

assert: procedure
  use arg condition, message
  if \condition then do
    say "ASSERT FAILED:" message
    exit 1
  end
return

::requires "../src/NoSQLServer.cls"

::requires "TestSupport.cls"
