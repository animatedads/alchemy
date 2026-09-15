sourceRoot = arg(1)
if sourceRoot = "" then do
  say "usage: v06_projection_alias_planner_smoke.rex DATABASE_ROOT"
  exit 2
end

root = .NoSQLServerTestSupport~createBlankDatabase("v06")
engine = .FileDatabaseEngine~new(root)
sql = .NoSQLServerSQL~new(engine)

call assertSuccess sql~execute("CREATE TABLE customer (customer_id INTEGER PRIMARY KEY, name VARCHAR, tier VARCHAR)"), "create customer"
call assertSuccess sql~execute("CREATE TABLE orders (order_id INTEGER PRIMARY KEY, customer_id INTEGER, total DECIMAL, state VARCHAR) WITH (SEPARATOR='HEX:FE')"), "create FE orders"

call assertSuccess sql~execute("INSERT INTO customer (customer_id,name,tier) VALUES (1,'Ada','gold')"), "customer Ada"
call assertSuccess sql~execute("INSERT INTO customer (customer_id,name,tier) VALUES (2,'Ben','silver')"), "customer Ben"
call assertSuccess sql~execute("INSERT INTO orders (order_id,customer_id,total,state) VALUES (100,1,10.5,'open')"), "order 100"
call assertSuccess sql~execute("INSERT INTO orders (order_id,customer_id,total,state) VALUES (101,1,20,'closed')"), "order 101"
call assertSuccess sql~execute("INSERT INTO orders (order_id,customer_id,total,state) VALUES (102,2,7.25,'open')"), "order 102"

-- Single-table aliases are normalized before planning, so a qualified WHERE can use a value index.
msg = engine~startIndexBuild("customer", "customer_id")
msg~wait
call assert (msg~errorCondition == .nil), "customer_id index build"
rs = sql~execute("SELECT c.name AS person, c.tier FROM customer AS c WHERE c.customer_id = 1")
call assertSuccess rs, "aliased single table projection"
call assert (rs~accessPath = "INDEX_CURRENT"), "qualified alias predicate retains index planning"
call assert (rs~rows~items = 1), "single projection row count"
call assert (rs~rows[1]["person"] = "Ada"), "column AS alias"
call assert (rs~rows[1]["c.tier"] = "gold"), "qualified projected output"

-- Without a join map, a simple post-join equality on one side can prefilter that side through its value index.
msg = engine~startIndexBuild("orders", "order_id")
msg~wait
call assert (msg~errorCondition == .nil), "order_id index build"
rs = sql~execute("SELECT c.name AS customer_name, o.total AS amount FROM customer c JOIN orders AS o ON c.customer_id = o.customer_id WHERE o.order_id = 101")
call assertSuccess rs, "join side-index prefilter"
call assert (rs~accessPath = "JOIN_PREFILTER_RIGHT_INDEX_CURRENT"), "join planner selects right value index"
call assert (rs~rows~items = 1), "prefiltered join exact row count"
call assert (rs~rows[1]["customer_name"] = "Ada"), "prefilter projection customer"
call assert (rs~rows[1]["amount"] = "20"), "prefilter projection amount"

-- Build the learned join map. Once present, it becomes the primary join accelerator and WHERE is applied relationally afterward.
do 3
  learn = sql~execute("SELECT * FROM customer c JOIN orders o ON c.customer_id = o.customer_id")
  call assertSuccess learn, "teach join shape"
end
messages = engine~adviseJoinMaps(3)
call assert (messages~items = 1), "advisor starts join map"
messages[1]~wait
call assert (messages[1]~errorCondition == .nil), "join map build"

-- With both accelerators available, the explicit cost model may prefer the selective value index.
costChoice = sql~execute("SELECT c.name AS customer_name, o.total AS amount FROM customer c JOIN orders o ON c.customer_id = o.customer_id WHERE o.order_id = 101")
call assertSuccess costChoice, "costed join plan"
call assert (costChoice~accessPath = "JOIN_PREFILTER_RIGHT_INDEX_CURRENT"), "cost model prefers selective value index over broader join map"

rs = sql~execute("SELECT c.name AS customer_name, o.order_id, o.total FROM customer AS c JOIN orders o ON c.customer_id = o.customer_id WHERE c.name = 'Ada'")
call assertSuccess rs, "post-join WHERE with aliases"
call assert (rs~accessPath = "JOIN_MAP_CURRENT"), "join map selected when current"
call assert (rs~rows~items = 2), "post-join predicate exact count"
call assert hasProjectedOrder(rs~rows, "Ada", "100", "10.5"), "projected order 100"
call assert hasProjectedOrder(rs~rows, "Ada", "101", "20"), "projected order 101"

-- Unqualified names that occur on both sides are rejected instead of guessed.
ambiguous = sql~execute("SELECT customer_id FROM customer c JOIN orders o ON c.customer_id = o.customer_id")
call assert (ambiguous~status = .Error~NOTEXECUTED), "ambiguous join projection rejected"
call assert (ambiguous~error = .Error~SQLPARSEERROR), "ambiguous projection parse error"

cleanupResult = .NoSQLServerTestSupport~removeDatabase(root)
say "NOSQLSERVER V0.6 PROJECTION ALIAS PLANNER SMOKE: OK"
exit 0

hasProjectedOrder: procedure
  use arg rows, name, orderId, total
  do row over rows
    if row["customer_name"] = name then do
      if row["o.order_id"] = orderId then do
        if row["o.total"] = total then return .true
      end
    end
  end
  return .false

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
