sourceRoot = arg(1)
if sourceRoot = "" then do
  say "usage: v051_concurrency_hardening_smoke.rex DATABASE_ROOT"
  exit 2
end

root = .NoSQLServerTestSupport~createBlankDatabase("v051")
engine1 = .FileDatabaseEngine~new(root)
engine2 = .FileDatabaseEngine~new(root)
sql = .NoSQLServerSQL~new(engine1)

call assertSuccess sql~execute("CREATE TABLE customer (customer_id INTEGER PRIMARY KEY, name VARCHAR)"), "create customer"
call assertSuccess sql~execute("CREATE TABLE orders (order_id INTEGER PRIMARY KEY, customer_id INTEGER, total DECIMAL) WITH (SEPARATOR='HEX:FE')"), "create orders"
call assertSuccess sql~execute("INSERT INTO customer (customer_id,name) VALUES (1,'Ada')"), "customer 1"
call assertSuccess sql~execute("INSERT INTO customer (customer_id,name) VALUES (2,'Ben')"), "customer 2"
call assertSuccess sql~execute("INSERT INTO orders (order_id,customer_id,total) VALUES (100,1,10)"), "order 100"
call assertSuccess sql~execute("INSERT INTO orders (order_id,customer_id,total) VALUES (101,2,20)"), "order 101"

-- Both engine objects in this ooRexx process must share one guarded pattern-log object.
call assert (engine1~queryPatternLog == engine2~queryPatternLog), "same root shares query-pattern log object"
messages = .array~new
do workerNo = 1 to 8
  worker = .PatternRecorder~new(engine1~queryPatternLog, 25)
  msg = .Message~new(worker, "RUN")
  msg~start
  messages~append(msg)
end
do msg over messages
  msg~wait
  call assert (msg~errorCondition == .nil), "concurrent pattern recorder completes"
end
patterns = .Yaml~new~parseFile(root || "/querylog/patterns.yaml")
item = patterns["JOIN.CUSTOMER.CUSTOMER_ID.ORDERS.CUSTOMER_ID"]
call assert (item \== .nil), "concurrent join pattern exists"
call assert (item["count"] = 200), "concurrent pattern increments are not lost"
call assert (stream(root || "/querylog/patterns.yaml.new", "c", "query exists") = ""), "no querylog temporary file leaked"
call assert (stream(root || "/querylog/patterns.yaml.old", "c", "query exists") = ""), "no querylog old file leaked"

-- In-flight suppression is runtime-shared across engine instances for the same database root.
buildKey = "JOIN.CUSTOMER.CUSTOMER_ID.ORDERS.CUSTOMER_ID"
call assert engine1~beginBuild(buildKey), "first engine claims build signature"
call assert (\engine2~beginBuild(buildKey)), "second engine cannot duplicate in-flight build"
call assert engine2~buildInFlight(buildKey), "second engine observes shared in-flight state"
call assert engine1~buildFinished(buildKey), "release shared build signature"
call assert (\engine2~buildInFlight(buildKey)), "released build signature disappears"

-- Build a real join map and then prove the left-side journal-hole mirror case.
msg = engine1~startJoinMapBuild("customer", "customer_id", "orders", "customer_id")
call assert (msg \== .nil), "join map build starts"
msg~wait
call assert (msg~errorCondition == .nil), "join map build completes"
snap = engine1~joinMapSnapshot("customer", "customer_id", "orders", "customer_id")
call assert (snap \== .nil), "join map published"
call assert (snap~relationTo(2,2) = "CURRENT"), "initial map current"

call assertSuccess sql~execute("UPDATE customer SET customer_id=3 WHERE customer_id=2"), "left key move"
call SysFileDelete root || "/tables/customer/journal/3.yaml"
call assertSuccess sql~execute("INSERT INTO customer (customer_id,name) VALUES (4,'Dee')"), "advance beyond left journal hole"
rs = sql~execute("SELECT * FROM customer JOIN orders ON customer.customer_id = orders.customer_id")
call assertSuccess rs, "join survives left journal hole"
call assert (rs~accessPath = "JOIN_TABLE_SCAN"), "left journal hole forces authoritative scan"
call assert (rs~rows~items = 1), "left-hole fallback exact row count"
call assert hasPair(rs~rows, "1", "100"), "left-hole fallback exact surviving pair"

-- Rebuild, then remove the map entirely. Missing derived state is also a scan, never an error.
msg2 = engine1~startJoinMapBuild("customer", "customer_id", "orders", "customer_id")
call assert (msg2 \== .nil), "join map rebuild starts"
msg2~wait
call assert (msg2~errorCondition == .nil), "join map rebuild completes"
mapPath = engine1~joinMapSnapshot("customer", "customer_id", "orders", "customer_id")~path
call SysFileDelete mapPath
call assert (engine1~joinMapSnapshot("customer", "customer_id", "orders", "customer_id") == .nil), "missing map snapshot is nil"
rs = sql~execute("SELECT * FROM customer JOIN orders ON customer.customer_id = orders.customer_id")
call assertSuccess rs, "join survives missing map"
call assert (rs~accessPath = "JOIN_TABLE_SCAN"), "missing map forces authoritative scan"
call assert (rs~rows~items = 1), "missing-map fallback exact row count"

-- Deterministic build-race simulation: left generation changes during the first scan.
-- The builder must discard that scan, retry, and publish only the stable generation.
leftProxy = .RacingTable~new(engine1~table("customer"), 10, 11)
rightProxy = .RacingTable~new(engine1~table("orders"), 20, 20)
raceRoot = root || "/racejoinmaps"
raceBuilder = .DatabaseJoinMapBuilder~new(leftProxy, "customer_id", rightProxy, "customer_id", raceRoot)
racePath = raceBuilder~build
call assert (racePath \== .nil), "race-simulated join map build succeeds"
raceRaw = .Yaml~new~parseFile(racePath)
call assert (raceRaw["leftIndexedThrough"] = 11), "builder publishes post-race stable left generation"
call assert (raceRaw["rightIndexedThrough"] = 20), "builder preserves stable right generation"
call assert (leftProxy~storage~reads >= 2), "generation movement forces a rescan"

cleanupResult = .NoSQLServerTestSupport~removeDatabase(root)
say "NOSQLSERVER V0.5.1 CONCURRENCY HARDENING SMOKE: OK"
exit 0

hasPair: procedure
  use arg rows, customerId, orderId
  do row over rows
    if row["customer.customer_id"] = customerId then do
      if row["orders.order_id"] = orderId then return .true
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

::class RacingTable
::attribute delegate
::attribute currentGeneration
::attribute nextGeneration
::attribute storage

::method init
  use arg delegate, currentGeneration, nextGeneration
  self~delegate = delegate
  self~currentGeneration = currentGeneration
  self~nextGeneration = nextGeneration
  self~storage = .RacingStorage~new(delegate~storage, self)

::method definition
  return self~delegate~definition

::method path
  return self~delegate~path

::method generation
  return self~currentGeneration

::method advanceDuringRead
  if self~currentGeneration \= self~nextGeneration then do
    self~currentGeneration = self~nextGeneration
    return .true
  end
  return .false

::method primaryKeySignature
  use arg row
  return self~delegate~primaryKeySignature(row)

::class RacingStorage
::attribute delegate
::attribute owner
::attribute reads

::method init
  use arg delegate, owner
  self~delegate = delegate
  self~owner = owner
  self~reads = 0

::method readRows
  self~reads += 1
  rows = self~delegate~readRows
  changed = self~owner~advanceDuringRead
  return rows

::class PatternRecorder
::attribute log
::attribute count

::method init
  use arg log, count
  self~log = log
  self~count = count

::method run
  do i = 1 to self~count
    self~log~recordJoin("customer", "customer_id", "orders", "customer_id", 2, 2)
  end
  return self~count

::requires "../src/NoSQLServer.cls"
::requires "TestSupport.cls"
