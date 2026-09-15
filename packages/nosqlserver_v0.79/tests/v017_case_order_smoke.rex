parse arg ignored
root = .NoSQLServerTestSupport~createBlankDatabase("v017_case")
db = .FileDatabaseEngine~new(root)
sql = .NoSQLServerSQL~new(db)

call assertSuccess sql~execute("CREATE TABLE customers (customer_id INTEGER PRIMARY KEY, full_name VARCHAR NOT NULL, city VARCHAR NOT NULL)"), "create customers"
call assertSuccess sql~execute("CREATE TABLE orders (order_id INTEGER PRIMARY KEY, customer_id INTEGER NOT NULL, order_date DATE NOT NULL, status VARCHAR NOT NULL)"), "create orders"
call assertSuccess sql~execute("INSERT INTO customers (customer_id,full_name,city) VALUES (1,'Ada','London'),(2,'Bob','Edinburgh'),(3,'Cara','London')"), "customers"
call assertSuccess sql~execute("INSERT INTO orders (order_id,customer_id,order_date,status) VALUES (100,1,'2026-01-02','SHIPPED'),(101,2,'2026-01-01','CANCELLED'),(102,3,'2026-01-03','RETURNED'),(103,1,'2026-01-04','RETURNED')"), "orders"

q = "SELECT o.order_id, o.status, c.full_name, o.order_date FROM orders o JOIN customers c ON c.customer_id = o.customer_id ORDER BY CASE o.status WHEN 'CANCELLED' THEN 3 WHEN 'RETURNED' THEN 2 ELSE 1 END, c.city || '-' || c.full_name, o.order_date DESC"
rs = sql~execute(q)
call assertSuccess rs, "CASE/concat ORDER BY"
call assert rs~rows~items = 4, "row count"
call assert rs~rows[1]["o.order_id"] = 100, "ELSE rank first"
call assert rs~rows[2]["o.order_id"] = 103, "RETURNED London/Ada before London/Cara"
call assert rs~rows[3]["o.order_id"] = 102, "RETURNED London/Cara"
call assert rs~rows[4]["o.order_id"] = 101, "CANCELLED rank last"
call assert db~version~supports("CASE_EXPRESSIONS"), "CASE capability"
call assert db~version~supports("STRING_CONCAT"), "concat capability"
call assert db~version~supports("ORDER_BY_EXPRESSIONS"), "ORDER expression capability"

cleanup = .NoSQLServerTestSupport~removeDatabase(root)
say "NOSQLSERVER V0.17 CASE/ORDER EXPRESSION SMOKE: OK"
exit 0

assertSuccess: procedure
  use arg rs, label
  if rs~status \= .Error~SUCCESS then do
    say "ASSERT FAILED:" label rs~status rs~error rs~message
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
