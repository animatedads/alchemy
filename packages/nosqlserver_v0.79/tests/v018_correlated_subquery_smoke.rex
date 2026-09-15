parse arg ignored
root = .NoSQLServerTestSupport~createBlankDatabase("v018_correlated")
db = .FileDatabaseEngine~new(root)
sql = .NoSQLServerSQL~new(db)

call assertSuccess sql~execute("CREATE TABLE customers (customer_id INTEGER PRIMARY KEY, full_name VARCHAR NOT NULL)"), "create customers"
call assertSuccess sql~execute("CREATE TABLE orders (order_id INTEGER PRIMARY KEY, customer_id INTEGER NOT NULL)"), "create orders"
call assertSuccess sql~execute("CREATE TABLE order_items (item_id INTEGER PRIMARY KEY, order_id INTEGER NOT NULL, quantity INTEGER NOT NULL, unit_price DECIMAL NOT NULL)"), "create items"
call assertSuccess sql~execute("INSERT INTO customers (customer_id,full_name) VALUES (1,'Ada'),(2,'Bob')"), "customers"
call assertSuccess sql~execute("INSERT INTO orders (order_id,customer_id) VALUES (100,1),(101,2),(102,1)"), "orders"
call assertSuccess sql~execute("INSERT INTO order_items (item_id,order_id,quantity,unit_price) VALUES (1,100,2,10.5),(2,100,1,4.0),(3,101,3,2.0)"), "items"

q = "SELECT o.order_id, " || -
    "(SELECT c.full_name FROM customers c WHERE c.customer_id = o.customer_id) AS customer_name, " || -
    "(SELECT SUM(oi.quantity * oi.unit_price) FROM order_items oi WHERE oi.order_id = o.order_id) AS order_total, " || -
    "(SELECT COUNT(*) FROM order_items oi2 WHERE oi2.order_id = o.order_id) AS item_count " || -
    "FROM orders o ORDER BY order_total DESC"
rs = sql~execute(q)
call assertSuccess rs, "correlated scalar query"
call assert rs~rows~items = 3, "three orders"
call assert rs~rows[1]["o.order_id"] = 100, "highest total first"
call assert rs~rows[1]["customer_name"] = "Ada", "correlated name"
call assert rs~rows[1]["order_total"] = 25, "aggregate expression total"
call assert rs~rows[1]["item_count"] = 2, "count correlated rows"
call assert rs~rows[2]["o.order_id"] = 101, "second total"
call assert rs~rows[2]["order_total"] = 6, "second aggregate"
call assert rs~rows[3]["o.order_id"] = 102, "empty aggregate last"
call assert rs~rows[3]["order_total"] == .nil, "SUM empty set is NULL"
call assert rs~rows[3]["item_count"] = 0, "COUNT empty set is zero"
call assert db~version~release \= "", "release exposed"
call assert db~version~supports("CORRELATED_SCALAR_SUBQUERY"), "correlated capability"
call assert db~version~supports("SELECT_LIST_SUBQUERY"), "select-list subquery capability"
call assert db~version~supports("AGGREGATE_EXPRESSIONS"), "aggregate expression capability"

cleanup = .NoSQLServerTestSupport~removeDatabase(root)
say "NOSQLSERVER V0.18 CORRELATED SUBQUERY SMOKE: OK"
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
