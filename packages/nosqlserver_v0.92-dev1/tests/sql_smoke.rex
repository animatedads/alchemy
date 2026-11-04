sourceRoot = arg(1)
if sourceRoot = "" then exit 2

root = .NoSQLServerTestSupport~cloneDatabase(sourceRoot, "sql")

db = .FileDatabaseEngine~new(root)
sql = .NoSQLServerSQL~new(db)

rs = sql~execute("INSERT INTO customer (customer_id, name, email) VALUES (10, 'Alice Example', 'alice@example.com')")
call assert (rs~status = .Error~SUCCESS), "SQL INSERT"

rs = sql~execute("SELECT * FROM customer WHERE customer_id = 10")
call assert (rs~rows~items = 1), "SQL SELECT WHERE"
call assert (rs~rows[1]["name"] = "Alice Example"), "SQL SELECT value"

rs = sql~execute("UPDATE customer SET name = 'Alice Updated' WHERE customer_id = 10")
call assert (rs~affectedRows = 1), "SQL UPDATE"
rs = sql~execute("SELECT * FROM customer WHERE customer_id = 10")
call assert (rs~rows[1]["name"] = "Alice Updated"), "SQL UPDATE persisted"

rs = sql~execute("INSERT INTO event_log (event_id, message) VALUES (7, 'tab table')")
call assert (rs~affectedRows = 1), "SQL insert TAB table"

rs = sql~execute("INSERT INTO telemetry (sensor_id, reading) VALUES (99, 21.75)")
call assert (rs~affectedRows = 1), "SQL insert FE table"
rs = sql~execute("SELECT * FROM telemetry WHERE sensor_id = 99")
call assert (rs~rows~items = 1), "SQL select FE table"

rs = sql~execute("DELETE FROM customer WHERE customer_id = 10")
call assert (rs~affectedRows = 1), "SQL DELETE"

cleanupResult = .NoSQLServerTestSupport~removeDatabase(root)
say "NOSQLSERVER SQL SMOKE: OK"
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
