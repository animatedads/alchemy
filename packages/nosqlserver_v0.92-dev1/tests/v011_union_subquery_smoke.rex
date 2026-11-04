parse arg ignored
root = .NoSQLServerTestSupport~createBlankDatabase("v011_union")
engine = .FileDatabaseEngine~new(root)
sql = .NoSQLServerSQL~new(engine)
call assertSuccess sql~execute("CREATE TABLE customers (customer_id INTEGER PRIMARY KEY, loyalty_tier VARCHAR(20) NOT NULL)")
call assertSuccess sql~execute("CREATE TABLE orders (order_id INTEGER PRIMARY KEY, customer_id INTEGER NOT NULL, employee_id INTEGER NOT NULL, order_date DATE NOT NULL, status VARCHAR(20) NOT NULL)")
call assertSuccess sql~execute("INSERT INTO customers (customer_id, loyalty_tier) VALUES (1,'GOLD'),(2,'SILVER'),(3,'BRONZE')")
call assertSuccess sql~execute("INSERT INTO orders (order_id,customer_id,employee_id,order_date,status) VALUES (1,1,9,'2026-01-03','PENDING'),(2,2,9,'2026-01-01','SHIPPED'),(3,1,9,'2026-01-02','DELIVERED'),(4,3,9,'2026-01-04','RETURNED')")
q = "SELECT * FROM orders WHERE status = 'PENDING' UNION SELECT * FROM orders WHERE status = 'SHIPPED' UNION SELECT * FROM orders WHERE customer_id IN (SELECT customer_id FROM customers WHERE loyalty_tier = 'GOLD') ORDER BY order_date"
rs = sql~execute(q)
call assertSuccess rs
call assert rs~accessPath = "UNION_DISTINCT", "union access path"
call assert rs~rows~items = 3, "union deduplicates overlap"
call assert rs~rows[1]["order_id"] = 2, "global order 1"
call assert rs~rows[2]["order_id"] = 3, "global order 2"
call assert rs~rows[3]["order_id"] = 1, "global order 3"
cleanup = .NoSQLServerTestSupport~removeDatabase(root)
say "NOSQLSERVER V0.11 UNION/SUBQUERY SMOKE: OK"
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
