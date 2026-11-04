root = .NoSQLServerTestSupport~createBlankDatabase("v08_multijoin")
engine = .FileDatabaseEngine~new(root)
sql = .NoSQLServerSQL~new(engine)

call assertSuccess sql~execute("CREATE TABLE customers (customer_id INTEGER PRIMARY KEY, full_name VARCHAR(100) NOT NULL, city VARCHAR(50) NOT NULL)")
call assertSuccess sql~execute("CREATE TABLE orders (order_id INTEGER PRIMARY KEY, customer_id INTEGER NOT NULL)")
call assertSuccess sql~execute("CREATE TABLE order_items (order_item_id INTEGER PRIMARY KEY, order_id INTEGER NOT NULL, product_id INTEGER NOT NULL)")
call assertSuccess sql~execute("CREATE TABLE products (product_id INTEGER PRIMARY KEY, category VARCHAR(50) NOT NULL)")

call assertSuccess sql~execute("INSERT INTO customers (customer_id, full_name, city) VALUES (1,'Ada','London'),(2,'Grace','New York')")
call assertSuccess sql~execute("INSERT INTO orders (order_id, customer_id) VALUES (10,1),(11,1),(20,2)")
call assertSuccess sql~execute("INSERT INTO products (product_id, category) VALUES (100,'Books'),(101,'Books'),(102,'Tools')")
call assertSuccess sql~execute("INSERT INTO order_items (order_item_id, order_id, product_id) VALUES (1,10,100),(2,10,101),(3,11,100),(4,11,102),(5,20,102)")

base = sql~execute("SELECT c.customer_id, c.full_name, c.city, p.category FROM customers c, orders o, order_items oi, products p WHERE o.customer_id = c.customer_id AND oi.order_id = o.order_id AND oi.product_id = p.product_id")
call assertSuccess base
call assertEqual 5, base~rows~items, "non-distinct row count"
call assertEqual "MULTI_COMMA_EQUIJOIN", base~accessPath, "multi-table equijoin access path"

dedup = sql~execute("SELECT DISTINCT c.customer_id, c.full_name, c.city, p.category FROM customers c, orders o, order_items oi, products p WHERE o.customer_id = c.customer_id AND oi.order_id = o.order_id AND oi.product_id = p.product_id")
call assertSuccess dedup
call assertEqual 3, dedup~rows~items, "distinct row count"
call assertEqual "MULTI_COMMA_EQUIJOIN", dedup~accessPath, "distinct retains planner path"

expected = .table~new
expected["1|Ada|London|Books"] = .true
expected["1|Ada|London|Tools"] = .true
expected["2|Grace|New York|Tools"] = .true
do row over dedup~rows
  sig = row["c.customer_id"] || "|" || row["c.full_name"] || "|" || row["c.city"] || "|" || row["p.category"]
  call assertTrue expected[sig] \== .nil, "unexpected DISTINCT row " || sig
  expected~remove(sig)
end
call assertEqual 0, expected~items, "all distinct rows returned"

-- Unqualified duplicate column names must remain ambiguous even in the N-table relation.
amb = sql~execute("SELECT customer_id FROM customers c, orders o WHERE o.customer_id = c.customer_id")
call assertEqual .Error~NOTEXECUTED, amb~status, "ambiguous projection rejected"
call assertEqual .Error~SQLPARSEERROR, amb~error, "ambiguous projection classified as parse error"

cleanupResult = .NoSQLServerTestSupport~removeDatabase(root)
say "NOSQLSERVER V0.8 MULTI-JOIN DISTINCT SMOKE: OK"
exit 0

assertSuccess: procedure
  use arg rs
  if rs~status \= .Error~SUCCESS then do
    say "ASSERT FAILED: expected SUCCESS got" rs~status rs~error rs~message
    exit 1
  end
  return

assertEqual: procedure
  use arg expected, actual, label
  if expected \== actual then do
    say "ASSERT FAILED:" label "expected=" expected "actual=" actual
    exit 1
  end
  return

assertTrue: procedure
  use arg value, label
  if \value then do
    say "ASSERT FAILED:" label
    exit 1
  end
  return

::requires "../src/NoSQLServer.cls"
::requires "TestSupport.cls"
