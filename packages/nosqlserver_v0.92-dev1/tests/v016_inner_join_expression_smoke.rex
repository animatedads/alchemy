parse arg ignored
root = .NoSQLServerTestSupport~createBlankDatabase("v016_inner")
db = .FileDatabaseEngine~new(root)
sql = .NoSQLServerSQL~new(db)

call assertSuccess sql~execute("CREATE TABLE customers (customer_id INTEGER PRIMARY KEY, full_name VARCHAR NOT NULL, city VARCHAR NOT NULL)"), "create customers"
call assertSuccess sql~execute("CREATE TABLE employees (employee_id INTEGER PRIMARY KEY, full_name VARCHAR NOT NULL)"), "create employees"
call assertSuccess sql~execute("CREATE TABLE products (product_id INTEGER PRIMARY KEY, product_name VARCHAR NOT NULL, category VARCHAR NOT NULL)"), "create products"
call assertSuccess sql~execute("CREATE TABLE orders (order_id INTEGER PRIMARY KEY, customer_id INTEGER NOT NULL, employee_id INTEGER NOT NULL, order_date DATE NOT NULL)"), "create orders"
call assertSuccess sql~execute("CREATE TABLE order_items (order_item_id INTEGER PRIMARY KEY, order_id INTEGER NOT NULL, product_id INTEGER NOT NULL, quantity INTEGER NOT NULL, unit_price DECIMAL NOT NULL)"), "create items"

call assertSuccess sql~execute("INSERT INTO customers (customer_id,full_name,city) VALUES (1,'Ada','London'),(2,'Bob','Edinburgh')"), "customers"
call assertSuccess sql~execute("INSERT INTO employees (employee_id,full_name) VALUES (10,'Eve'),(11,'Dan')"), "employees"
call assertSuccess sql~execute("INSERT INTO products (product_id,product_name,category) VALUES (20,'Widget','Toys'),(21,'Drill','Tools')"), "products"
call assertSuccess sql~execute("INSERT INTO orders (order_id,customer_id,employee_id,order_date) VALUES (100,1,10,'2026-01-02'),(101,1,11,'2026-02-03'),(102,2,10,'2026-03-04')"), "orders"
call assertSuccess sql~execute("INSERT INTO order_items (order_item_id,order_id,product_id,quantity,unit_price) VALUES (1000,100,20,2,5.50),(1001,101,21,3,7.25),(1002,102,20,1,9.00)"), "items"

q = "SELECT c.full_name, c.city, o.order_id, o.order_date, p.product_name, oi.quantity, (oi.quantity * oi.unit_price) AS line_total, e.full_name AS handled_by FROM customers c JOIN orders o ON o.customer_id = c.customer_id JOIN order_items oi ON oi.order_id = o.order_id JOIN products p ON p.product_id = oi.product_id JOIN employees e ON e.employee_id = o.employee_id ORDER BY c.city, c.full_name, o.order_date DESC, p.category, p.product_name, oi.quantity DESC"
rs = sql~execute(q)
call assertSuccess rs, "five-way inner join"
call assert rs~accessPath = "INNER_HASH_CHAIN", "inner chain access path"
call assert rs~rows~items = 3, "joined row count"
call assert rs~rows[1]["c.full_name"] = "Bob", "city sort first"
call assert rs~rows[2]["o.order_id"] = 101, "date DESC within Ada"
call assert rs~rows[3]["o.order_id"] = 100, "older Ada order last"
call assert rs~rows[2]["line_total"] = 21.75, "computed multiplication projection"
call assert rs~rows[2]["handled_by"] = "Dan", "aliased employee projection"
explicitRs = sql~execute("SELECT c.full_name, o.order_id, oi.quantity FROM customers c INNER JOIN orders o ON o.customer_id = c.customer_id INNER JOIN order_items oi ON oi.order_id = o.order_id ORDER BY o.order_id")
call assertSuccess explicitRs, "explicit INNER JOIN syntax"
call assert explicitRs~rows~items = 3, "explicit INNER JOIN row count"
call assert db~version~supports("MULTI_INNER_JOIN"), "multi inner capability"
call assert db~version~supports("PROJECTION_ARITHMETIC"), "projection arithmetic capability"

cleanup = .NoSQLServerTestSupport~removeDatabase(root)
say "NOSQLSERVER V0.16 INNER JOIN/EXPRESSION SMOKE: OK"
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
