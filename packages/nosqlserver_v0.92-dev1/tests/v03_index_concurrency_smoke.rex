sourceRoot = arg(1)
if sourceRoot = "" then do
  say "usage: v03_index_concurrency_smoke.rex DATABASE_ROOT"
  exit 2
end

root = .NoSQLServerTestSupport~createBlankDatabase("v03")

engine = .FileDatabaseEngine~new(root)
sql = .NoSQLServerSQL~new(engine)

rs = sql~execute("CREATE TABLE customer (customer_id INTEGER PRIMARY KEY, email VARCHAR UNIQUE, region VARCHAR)")
call assert (rs~status = .Error~SUCCESS), "create customer"
rs = sql~execute("CREATE TABLE orders (order_id INTEGER PRIMARY KEY, customer_id INTEGER, total DECIMAL) WITH (SEPARATOR='TAB')")
call assert (rs~status = .Error~SUCCESS), "create orders"

call assertSuccess sql~execute("INSERT INTO customer (customer_id,email,region) VALUES (1,'a@example.com','N')"), "customer 1"
call assertSuccess sql~execute("INSERT INTO customer (customer_id,email,region) VALUES (2,'b@example.com','S')"), "customer 2"
call assertSuccess sql~execute("INSERT INTO customer (customer_id,email,region) VALUES (3,'c@example.com','N')"), "customer 3"
call assertSuccess sql~execute("INSERT INTO orders (order_id,customer_id,total) VALUES (100,1,10.5)"), "order 100"
call assertSuccess sql~execute("INSERT INTO orders (order_id,customer_id,total) VALUES (101,1,20)"), "order 101"
call assertSuccess sql~execute("INSERT INTO orders (order_id,customer_id,total) VALUES (102,2,7.25)"), "order 102"

customer = engine~table("customer")
call assert (customer~generation = 3), "customer generation increments per mutation"
call assert (stream(customer~path || "/journal/3.yaml", "c", "query exists") \= ""), "generation journal exists"

-- Three identical query shapes make this an adaptive-index candidate.
do 3
  rs = sql~execute("SELECT * FROM customer WHERE email = 'a@example.com'")
  call assert (rs~rows~items = 1), "logged equality query"
end
patternPath = root || "/querylog/patterns.yaml"
call assert (stream(patternPath, "c", "query exists") \= ""), "query-pattern log created"
patterns = .Yaml~new~parseFile(patternPath)
entry = patterns["CUSTOMER.EMAIL.EQ"]
call assert (entry \== .nil), "normalized query shape present"
call assert (entry["count"] = 3), "query pattern counted"

messages = engine~adviseIndexes(3)
call assert (messages~items = 1), "advisor starts one concurrent index build"
msg = messages[1]
msg~wait
call assert msg~completed, "index build message completed"
call assert (msg~errorCondition == .nil), "index build activity has no error"
snapshot = msg~result
call assert (snapshot~state = "USABLE"), "published index snapshot usable"
call assert (snapshot~indexedThrough = 3), "index snapshot records build generation"
refs = snapshot~lookup("a@example.com")
call assert (refs~items = 1), "index maps value to primary-key reference"
call assert (refs[1] = "1"), "index primary-key signature"

-- The authoritative table can move ahead while the index remains usable-but-behind.
call assertSuccess sql~execute("INSERT INTO customer (customer_id,email,region) VALUES (4,'d@example.com','W')"), "customer after index"
current = engine~table("customer")
call assert (current~generation = 4), "table generation advances beyond index"
stale = engine~indexSnapshot("customer", "email")
call assert (stale~indexedThrough = 3), "index remains explicitly behind"
call assert (stale~relationTo(current~generation) = "BEHIND"), "snapshot reports BEHIND against current table"

-- Rebuild catches it up and atomically republishes the derived file.
msg2 = engine~startIndexBuild("customer", "email")
msg2~wait
call assert (msg2~errorCondition == .nil), "catch-up rebuild completes"
fresh = msg2~result
call assert (fresh~indexedThrough = 4), "rebuilt index catches up"
call assert (fresh~relationTo(current~generation) = "CURRENT"), "rebuilt snapshot reports CURRENT"
call assert (fresh~lookup("d@example.com")~items = 1), "new value appears in rebuilt index"

-- Join maps are also concurrent, disposable derived structures with independent watermarks.
joinMsg = engine~startJoinMapBuild("customer", "customer_id", "orders", "customer_id")
call assert (joinMsg \== .nil), "join-map build starts"
joinMsg~wait
call assert (joinMsg~errorCondition == .nil), "join-map build completes"
joinPath = joinMsg~result
call assert (stream(joinPath, "c", "query exists") \= ""), "join map published"
joinRaw = .Yaml~new~parseFile(joinPath)
call assert (joinRaw["type"] = "join-map"), "join map type"
call assert (joinRaw["leftIndexedThrough"] = 4), "join map left watermark"
call assert (joinRaw["rightIndexedThrough"] = 3), "join map right watermark"
keyOne = joinRaw["map"]["1"]
call assert (keyOne \== .nil), "join key 1 exists"
call assert (keyOne["left"]~items = 1), "join map left refs"
call assert (keyOne["right"]~items = 2), "join map right refs"

cleanupResult = .NoSQLServerTestSupport~removeDatabase(root)
say "NOSQLSERVER V0.3 INDEX CONCURRENCY SMOKE: OK"
exit 0

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
