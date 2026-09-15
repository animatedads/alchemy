parse arg ignored
root = .NoSQLServerTestSupport~createBlankDatabase("v021_coalesce")
engine = .FileDatabaseEngine~new(root)
sql = .NoSQLServerSQL~new(engine)

call assertSuccess sql~execute("CREATE TABLE customers (customer_id INTEGER PRIMARY KEY, full_name VARCHAR NOT NULL)")
call assertSuccess sql~execute("CREATE TABLE orders (order_id INTEGER PRIMARY KEY, customer_id INTEGER NOT NULL, order_date DATE NOT NULL)")
call assertSuccess sql~execute("CREATE TABLE order_items (item_id INTEGER PRIMARY KEY, order_id INTEGER NOT NULL, quantity INTEGER NOT NULL, unit_price DECIMAL NOT NULL)")
call assertSuccess sql~execute("INSERT INTO customers (customer_id,full_name) VALUES (1,'Ada'),(2,'Bob'),(3,'Cara')")
call assertSuccess sql~execute("INSERT INTO orders (order_id,customer_id,order_date) VALUES (100,1,'2026-01-01'),(101,1,'2026-02-01'),(102,2,'2025-12-01')")
call assertSuccess sql~execute("INSERT INTO order_items (item_id,order_id,quantity,unit_price) VALUES (1,100,2,10),(2,100,1,5),(3,101,3,2),(4,102,4,7.5)")

q = "SELECT c.customer_id, c.full_name, " || -
    "(SELECT COUNT(*) FROM orders o WHERE o.customer_id = c.customer_id) AS order_count, " || -
    "(SELECT COALESCE(SUM(oi.quantity*oi.unit_price),0) " || -
       "FROM orders o JOIN order_items oi ON oi.order_id = o.order_id " || -
       "WHERE o.customer_id = c.customer_id) AS lifetime_value, " || -
    "(SELECT MAX(o.order_date) FROM orders o WHERE o.customer_id = c.customer_id) AS last_order " || -
    "FROM customers c ORDER BY lifetime_value DESC"
rs = sql~execute(q)
call assertSuccess rs
call assert rs~rows~items = 3, "three customers"
call assert rs~rows[1]["c.customer_id"] = 1, "Ada first"
call assert rs~rows[1]["order_count"] = 2, "Ada order count"
call assert rs~rows[1]["lifetime_value"] = 31, "Ada lifetime"
call assert rs~rows[1]["last_order"] = "2026-02-01", "Ada last order"
call assert rs~rows[2]["c.customer_id"] = 2, "Bob second"
call assert rs~rows[2]["order_count"] = 1, "Bob order count"
call assert rs~rows[2]["lifetime_value"] = 30, "Bob lifetime"
call assert rs~rows[3]["c.customer_id"] = 3, "Cara last"
call assert rs~rows[3]["order_count"] = 0, "empty COUNT is zero"
call assert rs~rows[3]["lifetime_value"] = 0, "COALESCE empty SUM is zero"
call assert rs~rows[3]["last_order"] == .nil, "empty MAX is NULL"

-- An unaliased scalar subquery is valid SQL and must not require AS accidentally.
rs = sql~execute("SELECT c.customer_id, (SELECT COUNT(*) FROM orders o WHERE o.customer_id = c.customer_id) FROM customers c ORDER BY c.customer_id")
call assertSuccess rs
call assert rs~rows~items = 3, "unaliased scalar rows"

v = engine~version
call assert v~product = "NoSQLServer", "version product"
call assert v~supports("COALESCE"), "COALESCE capability"
call assert v~supports("CORRELATED_AGGREGATE_SUBQUERY"), "correlated aggregate capability"

cleanup = .NoSQLServerTestSupport~removeDatabase(root)
say "NOSQLSERVER V0.21 CORRELATED AGGREGATE/COALESCE SMOKE: OK"
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
