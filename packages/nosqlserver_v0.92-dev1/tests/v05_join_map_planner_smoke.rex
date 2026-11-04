sourceRoot = arg(1)
if sourceRoot = "" then do
  say "usage: v05_join_map_planner_smoke.rex DATABASE_ROOT"
  exit 2
end

root = .NoSQLServerTestSupport~createBlankDatabase("v05")
engine = .FileDatabaseEngine~new(root)
sql = .NoSQLServerSQL~new(engine)

call assertSuccess sql~execute("CREATE TABLE customer (customer_id INTEGER PRIMARY KEY, name VARCHAR)"), "create customer"
call assertSuccess sql~execute("CREATE TABLE orders (order_id INTEGER PRIMARY KEY, customer_id INTEGER, total DECIMAL) WITH (SEPARATOR='HEX:FE')"), "create orders FE"

call assertSuccess sql~execute("INSERT INTO customer (customer_id,name) VALUES (1,'Ada')"), "customer 1"
call assertSuccess sql~execute("INSERT INTO customer (customer_id,name) VALUES (2,'Ben')"), "customer 2"
call assertSuccess sql~execute("INSERT INTO customer (customer_id,name) VALUES (3,'Cy')"), "customer 3"
call assertSuccess sql~execute("INSERT INTO orders (order_id,customer_id,total) VALUES (100,1,10.5)"), "order 100"
call assertSuccess sql~execute("INSERT INTO orders (order_id,customer_id,total) VALUES (101,1,20)"), "order 101"
call assertSuccess sql~execute("INSERT INTO orders (order_id,customer_id,total) VALUES (102,2,7.25)"), "order 102"

-- Without a join map, SQL must still be correct through authoritative hash-join scan.
-- Repeating the same shape teaches the advisor that this join deserves a map.
do 3
  rs = sql~execute("SELECT * FROM customer JOIN orders ON customer.customer_id = orders.customer_id")
  call assertSuccess rs, "scan join succeeds"
  call assert (rs~accessPath = "JOIN_TABLE_SCAN"), "no map means join table scan"
  call assert (rs~rows~items = 3), "scan join row count"
end
call assert hasPair(rs~rows, "1", "100"), "scan pair 1/100"
call assert hasPair(rs~rows, "1", "101"), "scan pair 1/101"
call assert hasPair(rs~rows, "2", "102"), "scan pair 2/102"
patterns = .Yaml~new~parseFile(root || "/querylog/patterns.yaml")
joinPattern = patterns["JOIN.CUSTOMER.CUSTOMER_ID.ORDERS.CUSTOMER_ID"]
call assert (joinPattern \== .nil), "normalized join query shape logged"
call assert (joinPattern["count"] = 3), "join pattern counted"

-- Advisor launches the map build concurrently across comma and FE-delimited sources.
messages = engine~adviseJoinMaps(3)
call assert (messages~items = 1), "join advisor starts one concurrent map build"
msg = messages[1]
msg~wait
call assert (msg~errorCondition == .nil), "join-map build completes"
joinPath = msg~result
call assert (stream(joinPath, "c", "query exists") \= ""), "join-map file published"
snap = engine~joinMapSnapshot("customer", "customer_id", "orders", "customer_id")
call assert (snap \== .nil), "join-map snapshot opens"
call assert (snap~relationTo(3,3) = "CURRENT"), "initial join map current"
call assert (snap~leftIndexedThrough = 3), "left watermark 3"
call assert (snap~rightIndexedThrough = 3), "right watermark 3"

rs = sql~execute("SELECT * FROM customer JOIN orders ON customer.customer_id = orders.customer_id")
call assertSuccess rs, "current map join succeeds"
call assert (rs~accessPath = "JOIN_MAP_CURRENT"), "planner consumes current join map"
call assert (rs~rows~items = 3), "current map row count"
call assert (rs~leftIndexedThrough = 3), "result left watermark"
call assert (rs~rightIndexedThrough = 3), "result right watermark"

-- Advance both sides after map publication. This exercises INSERT, UPDATE-out,
-- UPDATE-in and DELETE reconciliation independently on each table.
call assertSuccess sql~execute("INSERT INTO customer (customer_id,name) VALUES (4,'Dee')"), "customer 4"
call assertSuccess sql~execute("UPDATE customer SET customer_id=5 WHERE customer_id = 2"), "left join key moves 2 to 5"
call assertSuccess sql~execute("INSERT INTO orders (order_id,customer_id,total) VALUES (103,4,11)"), "right insert key 4"
call assertSuccess sql~execute("UPDATE orders SET customer_id=5 WHERE order_id = 102"), "right key moves 2 to 5"
call assertSuccess sql~execute("DELETE FROM orders WHERE order_id = 101"), "delete joined order"

call assert (engine~table("customer")~generation = 5), "left generation 5"
call assert (engine~table("orders")~generation = 6), "right generation 6"
snap = engine~joinMapSnapshot("customer", "customer_id", "orders", "customer_id")
call assert (snap~relationTo(5,6) = "BEHIND"), "join map explicitly behind"

rs = sql~execute("SELECT * FROM customer JOIN orders ON customer.customer_id = orders.customer_id")
call assertSuccess rs, "delta join succeeds"
call assert (rs~accessPath = "JOIN_MAP_DELTA"), "planner reconciles join-map deltas"
call assert (rs~rows~items = 3), "delta join exact row count"
call assert hasPair(rs~rows, "1", "100"), "surviving pair 1/100"
call assert hasPair(rs~rows, "4", "103"), "inserted pair 4/103"
call assert hasPair(rs~rows, "5", "102"), "both-side moved-key pair 5/102"
call assert (\hasOrder(rs~rows, "101")), "deleted order absent"

-- A journal hole invalidates reconciliation. The map remains disposable and
-- correctness wins: use an authoritative scan rather than partial deltas.
call SysFileDelete root || "/tables/orders/journal/6.yaml"
call assertSuccess sql~execute("INSERT INTO orders (order_id,customer_id,total) VALUES (104,4,12)"), "advance beyond right journal hole"
rs = sql~execute("SELECT * FROM customer JOIN orders ON customer.customer_id = orders.customer_id")
call assertSuccess rs, "join survives journal hole"
call assert (rs~accessPath = "JOIN_TABLE_SCAN"), "journal hole forces authoritative join scan"
call assert (rs~rows~items = 4), "fallback join remains exact"
call assert hasPair(rs~rows, "4", "104"), "fallback sees newest order"

-- Rebuild catches both independent watermarks up and republishes atomically.
msg2 = engine~startJoinMapBuild("customer", "customer_id", "orders", "customer_id")
msg2~wait
call assert (msg2~errorCondition == .nil), "join-map rebuild completes"
fresh = engine~joinMapSnapshot("customer", "customer_id", "orders", "customer_id")
call assert (fresh~relationTo(5,7) = "CURRENT"), "rebuilt join map current"
rs = sql~execute("SELECT * FROM customer JOIN orders ON customer.customer_id = orders.customer_id")
call assertSuccess rs, "rebuilt current join succeeds"
call assert (rs~accessPath = "JOIN_MAP_CURRENT"), "planner returns to current join map"
call assert (rs~rows~items = 4), "rebuilt map result exact"

cleanupResult = .NoSQLServerTestSupport~removeDatabase(root)
say "NOSQLSERVER V0.5 JOIN MAP PLANNER SMOKE: OK"
exit 0

hasPair: procedure
  use arg rows, customerId, orderId
  do row over rows
    if row["customer.customer_id"] = customerId then do
      if row["orders.order_id"] = orderId then return .true
    end
  end
  return .false

hasOrder: procedure
  use arg rows, orderId
  do row over rows
    if row["orders.order_id"] = orderId then return .true
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
