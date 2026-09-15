parse arg ignored
root = .NoSQLServerTestSupport~createBlankDatabase("v013_aggregate")
engine = .FileDatabaseEngine~new(root)
sql = .NoSQLServerSQL~new(engine)

call assertSuccess sql~execute("CREATE TABLE metrics (id INTEGER PRIMARY KEY, category VARCHAR, amount DECIMAL, qty INTEGER, note VARCHAR)")
call assertSuccess sql~execute("INSERT INTO metrics (id,category,amount,qty,note) VALUES (1,'A',10.5,2,'x'),(2,'A',5.5,3,NULL),(3,'B',20,4,'y'),(4,'B',NULL,1,NULL),(5,'B',5,2,'z')")

rs = sql~execute("SELECT category, COUNT(*) AS n, COUNT(note) AS notes, SUM(amount) AS total, AVG(amount) AS mean, MIN(amount) AS low, MAX(amount) AS high FROM metrics GROUP BY category ORDER BY category")
call assertSuccess rs
call assert rs~rows~items = 2, "two aggregate groups"
call assert rs~rows[1]["category"] = "A", "group A first"
call assert rs~rows[1]["n"] = 2, "COUNT star A"
call assert rs~rows[1]["notes"] = 1, "COUNT column ignores NULL"
call assert rs~rows[1]["total"] = 16, "SUM A"
call assert rs~rows[1]["mean"] = 8, "AVG A"
call assert rs~rows[1]["low"] = "5.5", "MIN A"
call assert rs~rows[1]["high"] = "10.5", "MAX A"
call assert rs~rows[2]["category"] = "B", "group B second"
call assert rs~rows[2]["n"] = 3, "COUNT star B"
call assert rs~rows[2]["notes"] = 2, "COUNT column B"
call assert rs~rows[2]["total"] = 25, "SUM ignores NULL"
call assert rs~rows[2]["mean"] = 12.5, "AVG ignores NULL"
call assert rs~rows[2]["low"] = "5", "MIN B"
call assert rs~rows[2]["high"] = "20", "MAX B"

rs = sql~execute("SELECT COUNT(*) AS n, SUM(qty) AS qty_total, AVG(qty) AS qty_mean FROM metrics WHERE category = 'B'")
call assertSuccess rs
call assert rs~rows~items = 1, "ungrouped aggregate one row"
call assert rs~rows[1]["n"] = 3, "ungrouped count"
call assert rs~rows[1]["qty_total"] = 7, "ungrouped sum"

rs = sql~execute("SELECT category, COUNT(*) FROM metrics")
call assert rs~status = .Error~NOTEXECUTED, "mixed projection rejected without GROUP BY"
call assert rs~error = .Error~SQLPARSEERROR, "mixed projection parse classification"

rs = sql~execute("SELECT category, COUNT(*) FROM metrics GROUP BY qty")
call assert rs~status = .Error~NOTEXECUTED, "projection not in GROUP BY rejected"
call assert rs~error = .Error~SQLPARSEERROR, "group projection parse classification"

rs = sql~execute("SELECT category, SUM(note) FROM metrics GROUP BY category")
call assert rs~status = .Error~NOTEXECUTED, "SUM varchar refused"
call assert rs~error = .Error~SQLUNSUPPORTED, "SUM varchar unsupported classification"

rs = sql~execute("SELECT category, COUNT(*) AS n FROM metrics GROUP BY category HAVING COUNT(*) > 1 ORDER BY category")
call assertSuccess rs
call assert rs~rows~items = 2, "HAVING now filters aggregate groups"
call assert rs~rows[1]["category"] = "A", "HAVING group A"
call assert rs~rows[2]["category"] = "B", "HAVING group B"

cleanup = .NoSQLServerTestSupport~removeDatabase(root)
say "NOSQLSERVER V0.13 AGGREGATE/GROUP BY SMOKE: OK"
exit 0

assertSuccess: procedure
  use arg rs
  if rs~status \= .Error~SUCCESS then do
    say "ASSERT FAILED: expected success" rs~error rs~message
    exit 1
  end
  return
assert: procedure
  use arg condition, message
  if \condition then do
    say "ASSERT FAILED:" message
    exit 1
  end
  return
::requires "../src/NoSQLServer.cls"
::requires "TestSupport.cls"
