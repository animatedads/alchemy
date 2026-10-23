sourceRoot = arg(1)
if sourceRoot = "" then do
  say "usage: v061_torture_harness_smoke.rex DATABASE_ROOT"
  exit 2
end

root = .NoSQLServerTestSupport~createBlankDatabase("v061")
engine = .FileDatabaseEngine~new(root)
sql = .NoSQLServerSQL~new(engine)

-- Parameterized SQL type declarations from Claude's corpus normalize to the supported logical types.
rs = sql~execute("CREATE TABLE products (product_id INTEGER PRIMARY KEY, product_name VARCHAR(100) NOT NULL, unit_price DECIMAL(10,2) NOT NULL, created DATE)")
call assertSuccess rs, "parameterized type DDL"

-- Batched VALUES tuples are all consumed; no trailing tuples may disappear silently.
rs = sql~execute("INSERT INTO products (product_id,product_name,unit_price,created) VALUES (1,'One',10.25,'2026-08-01'), (2,'Two',20.50,'2026-08-02'), (3,'Three',30.75,'2026-08-03')")
call assertSuccess rs, "three-row batched INSERT"
call assert (rs~affectedRows = 3), "batched INSERT affected rows"
check = sql~execute("SELECT * FROM products")
call assertSuccess check, "select after batch"
call assert (check~rows~items = 3), "all batch tuples persisted"

-- A failing tuple makes the whole VALUES statement fail before any new table image is published.
rs = sql~execute("INSERT INTO products (product_id,product_name,unit_price,created) VALUES (4,'Four',40,'2026-08-04'), (2,'Duplicate PK',50,'2026-08-05')")
call assert (rs~status = .Error~NOTEXECUTED), "bad batch rejected"
call assert (rs~error = .Error~CONSTRAINT), "bad batch constraint classification"
check = sql~execute("SELECT * FROM products")
call assertSuccess check, "select after rejected batch"
call assert (check~rows~items = 3), "rejected batch is atomic"

-- FK syntax is not silently accepted while FK enforcement is absent.
fk = sql~execute("CREATE TABLE child (child_id INTEGER PRIMARY KEY, product_id INTEGER REFERENCES products(product_id))")
call assert (fk~status = .Error~NOTEXECUTED), "FK DDL rejected"
call assert (fk~error = .Error~SQLUNSUPPORTED), "FK classified unsupported"

-- Known grammar outside the implemented surface is planner/parser capability refusal, not malformed SQL.
-- GROUP BY and RIGHT/FULL JOIN are now supported, so retain this classification test on a
-- capability that is still deliberately outside the current surface.
unsupported = sql~execute("WITH x AS (SELECT product_id FROM products) SELECT product_id FROM x")
call assert (unsupported~status = .Error~NOTEXECUTED), "CTE refused"
call assert (unsupported~error = .Error~SQLUNSUPPORTED), "CTE classified unsupported"

malformed = sql~execute("SELECT FROM products")
call assert (malformed~status = .Error~NOTEXECUTED), "malformed SELECT rejected"
call assert (malformed~error = .Error~SQLPARSEERROR), "malformed SELECT classified parse error"

cleanupResult = .NoSQLServerTestSupport~removeDatabase(root)
say "NOSQLSERVER V0.6.1 TORTURE HARNESS SMOKE: OK"
exit 0

assertSuccess: procedure
  use arg rs, message
  if rs~status \= .Error~SUCCESS then do
    say "ASSERT FAILED:" message rs~error rs~message
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
