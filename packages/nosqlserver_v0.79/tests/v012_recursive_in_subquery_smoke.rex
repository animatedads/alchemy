parse arg ignored
root = .NoSQLServerTestSupport~createBlankDatabase("v012_recursive_in")
engine = .FileDatabaseEngine~new(root)
sql = .NoSQLServerSQL~new(engine)

call assertSuccess sql~execute("CREATE TABLE customers (customer_id INTEGER PRIMARY KEY, city VARCHAR(50) NOT NULL, loyalty_tier VARCHAR(20) NOT NULL)")
call assertSuccess sql~execute("CREATE TABLE orders (order_id INTEGER PRIMARY KEY, customer_id INTEGER NOT NULL)")
call assertSuccess sql~execute("CREATE TABLE order_items (order_item_id INTEGER PRIMARY KEY, order_id INTEGER NOT NULL, product_id INTEGER NOT NULL)")
call assertSuccess sql~execute("CREATE TABLE products (product_id INTEGER PRIMARY KEY, product_name VARCHAR(100) NOT NULL)")

call assertSuccess sql~execute("INSERT INTO customers (customer_id,city,loyalty_tier) VALUES (1,'Glasgow','PLATINUM'),(2,'Glasgow','BRONZE'),(3,'London','GOLD'),(4,'York','PLATINUM')")
call assertSuccess sql~execute("INSERT INTO orders (order_id,customer_id) VALUES (10,1),(11,2),(12,3),(13,4)")
call assertSuccess sql~execute("INSERT INTO order_items (order_item_id,order_id,product_id) VALUES (100,10,1000),(101,11,1001),(102,12,1002),(103,13,1003),(104,13,1000)")
call assertSuccess sql~execute("INSERT INTO products (product_id,product_name) VALUES (1000,'Alpha'),(1001,'Bravo'),(1002,'Charlie'),(1003,'Delta'),(1004,'Echo')")

q = "SELECT * FROM products WHERE product_id IN ( SELECT product_id FROM order_items WHERE order_id IN ( SELECT order_id FROM orders WHERE customer_id IN ( SELECT customer_id FROM customers WHERE city IN ( SELECT city FROM customers WHERE loyalty_tier = 'PLATINUM' ) ) ) )"
rs = sql~execute(q)
call assertSuccess rs
call assert rs~rows~items = 3, "recursive IN result count"
seen = .table~new
do row over rs~rows
  seen[row["product_id"]~string] = .true
end
call assert seen["1000"] \== .nil, "recursive IN product 1000"
call assert seen["1001"] \== .nil, "same-city customer included"
call assert seen["1003"] \== .nil, "second platinum city included"
call assert seen["1002"] == .nil, "nonqualifying city excluded"
call assert seen["1004"] == .nil, "unreferenced product excluded"

-- One more nesting level is deliberately exercised through the same executor,
-- proving recursion rather than a hard-coded four-level implementation.
q2 = "SELECT customer_id FROM customers WHERE city IN ( SELECT city FROM customers WHERE customer_id IN ( SELECT customer_id FROM customers WHERE city IN ( SELECT city FROM customers WHERE customer_id IN ( SELECT customer_id FROM customers WHERE loyalty_tier = 'PLATINUM' ) ) ) )"
rs2 = sql~execute(q2)
call assertSuccess rs2
call assert rs2~rows~items >= 1, "deeper recursive IN executes"

cleanup = .NoSQLServerTestSupport~removeDatabase(root)
say "NOSQLSERVER V0.12 RECURSIVE IN SUBQUERY SMOKE: OK"
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
