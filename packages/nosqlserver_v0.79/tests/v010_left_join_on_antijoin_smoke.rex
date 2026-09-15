root = .NoSQLServerTestSupport~createBlankDatabase("v010")
engine = .FileDatabaseEngine~new(root)
sql = .NoSQLServerSQL~new(engine)

call assertSuccess sql~execute("CREATE TABLE customers (customer_id INTEGER PRIMARY KEY, full_name VARCHAR(100) NOT NULL);"), "create customers"
call assertSuccess sql~execute("CREATE TABLE orders (order_id INTEGER PRIMARY KEY, customer_id INTEGER NOT NULL, status VARCHAR(20) NOT NULL);"), "create orders"
call assertSuccess sql~execute("INSERT INTO customers (customer_id,full_name) VALUES (1,'Cancelled Only'), (2,'Has Shipped'), (3,'No Orders'), (4,'Mixed Orders');"), "insert customers"
call assertSuccess sql~execute("INSERT INTO orders (order_id,customer_id,status) VALUES (10,1,'CANCELLED'), (20,2,'SHIPPED'), (30,4,'CANCELLED'), (31,4,'RETURNED');"), "insert orders"

q = "SELECT c.customer_id, c.full_name FROM customers c LEFT JOIN orders o ON o.customer_id = c.customer_id AND o.status <> 'CANCELLED' WHERE o.order_id IS NULL ORDER BY c.full_name;"
rs = sql~execute(q)
call assertSuccess rs, "anti join with ON filter"
call assertEq rs~accessPath, "LEFT_HASH_CHAIN", "access path"
call assertEq rs~rows~items, 2, "anti join row count"
call assertEq rs~rows[1]["c.full_name"], "Cancelled Only", "cancelled-only customer preserved"
call assertEq rs~rows[2]["c.full_name"], "No Orders", "no-order customer preserved"

-- Prove the ON predicate is not accidentally treated as a WHERE predicate.
q2 = "SELECT c.customer_id, c.full_name, o.status FROM customers c LEFT JOIN orders o ON o.customer_id = c.customer_id AND o.status <> 'CANCELLED' ORDER BY c.customer_id;"
rs2 = sql~execute(q2)
call assertSuccess rs2, "outer join ON-only semantics"
call assertEq rs2~rows~items, 4, "one logical row per customer in fixture"
seen = .table~new
do row over rs2~rows
  seen[row["c.customer_id"]] = row
end
call assertTrue seen["1"]["o.status"] == .nil, "cancelled-only match becomes NULL extension"
call assertEq seen["2"]["o.status"], "SHIPPED", "non-cancelled match retained"
call assertTrue seen["3"]["o.status"] == .nil, "no physical match becomes NULL extension"
call assertEq seen["4"]["o.status"], "RETURNED", "cancelled candidate ignored, returned retained"

cleanupResult = .NoSQLServerTestSupport~removeDatabase(root)
say "NOSQLSERVER V0.10 LEFT JOIN ON/ANTI-JOIN SMOKE: OK"
exit 0

assertSuccess: procedure
  use arg rs, label
  if rs~status \= .Error~SUCCESS then do
    say "ASSERT FAILED:" label "status=" rs~status "error=" rs~error "message=" rs~message
    exit 1
  end
  return

assertEq: procedure
  use arg actual, expected, label
  if actual \= expected then do
    say "ASSERT FAILED:" label "expected=" expected "actual=" actual
    exit 1
  end
  return

assertTrue: procedure
  use arg condition, label
  if \condition then do
    say "ASSERT FAILED:" label
    exit 1
  end
  return

::requires "../src/NoSQLServer.cls"
::requires "TestSupport.cls"
