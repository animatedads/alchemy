sourceRoot = arg(1)
if sourceRoot = "" then do
  say "usage: v07_cost_crossjoin_smoke.rex DATABASE_ROOT"
  exit 2
end
root = .NoSQLServerTestSupport~createBlankDatabase("v07")
engine = .FileDatabaseEngine~new(root)
sql = .NoSQLServerSQL~new(engine)

rs = sql~execute("CREATE TABLE customers (customer_id INTEGER PRIMARY KEY, full_name VARCHAR(100), city VARCHAR(50))")
call assertSuccess rs, "create customers"
rs = sql~execute("CREATE TABLE employees (employee_id INTEGER PRIMARY KEY, full_name VARCHAR(100), department VARCHAR(50)) WITH (SEPARATOR='HEX:FE')")
call assertSuccess rs, "create employees"
rs = sql~execute("INSERT INTO customers (customer_id,full_name,city) VALUES (1,'Ada','Glasgow'),(2,'Bob','London'),(3,'Cara','Glasgow')")
call assertSuccess rs, "insert customers"
rs = sql~execute("INSERT INTO employees (employee_id,full_name,department) VALUES (10,'Eve','IT'),(11,'Dan','Finance'),(12,'Fay','IT')")
call assertSuccess rs, "insert employees"

q = sql~execute("SELECT c.full_name, e.full_name, e.department FROM customers c, employees e WHERE c.city = 'Glasgow' ORDER BY e.department")
call assertSuccess q, "cross join query"
call assert (q~rows~items = 6), "cross join row count"
call assert (q~accessPath~startsWith("CROSS_PREFILTER_LEFT_")), "cross join prefilter path"
call assert (q~rows[1]["e.department"] = "Finance"), "ORDER BY first department"
call assert (q~rows[2]["e.department"] = "Finance"), "ORDER BY second department"
call assert (q~rows[3]["e.department"] = "IT"), "ORDER BY remaining departments"

cleanupResult = .NoSQLServerTestSupport~removeDatabase(root)
say "NOSQLSERVER V0.7 COST/CROSS-JOIN SMOKE: OK"
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
