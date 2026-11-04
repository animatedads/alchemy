parse arg ignored
root = .NoSQLServerTestSupport~createBlankDatabase("v020_having")
engine = .FileDatabaseEngine~new(root)
sql = .NoSQLServerSQL~new(engine)

call assertSuccess sql~execute("CREATE TABLE products (product_id INTEGER PRIMARY KEY, category VARCHAR)")
call assertSuccess sql~execute("CREATE TABLE items (item_id INTEGER PRIMARY KEY, product_id INTEGER, qty INTEGER, price DECIMAL)")
call assertSuccess sql~execute("INSERT INTO products (product_id,category) VALUES (1,'A'),(2,'B'),(3,'C')")
call assertSuccess sql~execute("INSERT INTO items (item_id,product_id,qty,price) VALUES (1,1,2,10),(2,1,1,5),(3,2,1,100),(4,3,1,10),(5,3,1,10)")

query = "SELECT p.category, COUNT(*) AS items_sold, SUM(i.qty * i.price) AS revenue " || -
        "FROM items i JOIN products p ON p.product_id = i.product_id " || -
        "GROUP BY p.category " || -
        "HAVING SUM(i.qty * i.price) > (" || -
          "SELECT AVG(sub.cat_revenue) FROM (" || -
            "SELECT p2.category, SUM(i2.qty * i2.price) AS cat_revenue " || -
            "FROM items i2 JOIN products p2 ON p2.product_id = i2.product_id " || -
            "GROUP BY p2.category" || -
          ") sub" || -
        ") ORDER BY revenue DESC"
rs = sql~execute(query)
call assertSuccess rs
call assert rs~rows~items = 1, "one category above average"
call assert rs~rows[1]["p.category"] = "B", "category B above average"
call assert rs~rows[1]["items_sold"] = 1, "count B"
call assert rs~rows[1]["revenue"] = 100, "revenue B"
call assert rs~accessPath~pos("AGGREGATE_INNER_HASH_CHAIN") = 1, "aggregate join access path"

-- Plain HAVING over one table is also part of the same general surface.
rs = sql~execute("SELECT product_id, COUNT(*) AS n FROM items GROUP BY product_id HAVING COUNT(*) > 1 ORDER BY product_id")
call assertSuccess rs
call assert rs~rows~items = 2, "simple HAVING groups"
call assert rs~rows[1]["product_id"] = 1, "simple HAVING product 1"
call assert rs~rows[2]["product_id"] = 3, "simple HAVING product 3"

v = engine~version
call assert v~release \= "", "release exposed"
call assert v~supports("HAVING"), "HAVING capability"
call assert v~supports("DERIVED_TABLES"), "derived-table capability"
call assert v~supports("AGGREGATE_JOIN_SOURCES"), "aggregate join capability"
call assert v~supports("DERIVED_AGGREGATES"), "derived aggregate capability"

cleanup = .NoSQLServerTestSupport~removeDatabase(root)
say "NOSQLSERVER V0.20 HAVING/DERIVED AGGREGATE SMOKE: OK"
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
