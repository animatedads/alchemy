parse arg ignored
root = .NoSQLServerTestSupport~createBlankDatabase("v015_scalar")
db = .FileDatabaseEngine~new(root)
sql = .NoSQLServerSQL~new(db)

call assertSuccess sql~execute("CREATE TABLE customers (id INTEGER PRIMARY KEY, email VARCHAR NOT NULL, city VARCHAR NOT NULL, score INTEGER NOT NULL)"), "create customers"
call assertSuccess sql~execute("INSERT INTO customers (id,email,city,score) VALUES (1,'alice@example.com','London',10),(2,'zed@example.com','London',15),(3,'mary@example.com','Boston',20),(4,'bob@example.com','Glasgow',25),(5,'ian@example.com','on',30)"), "insert scalar rows"

q = "SELECT * FROM customers WHERE UPPER(city) LIKE '%ON%' AND LOWER(SUBSTR(email,1,1)) BETWEEN 'a' AND 'm' ORDER BY id"
rs = sql~execute(q)
call assertSuccess rs, "function wrapped predicate"
call assert rs~rows~items = 3, "wrapped predicate row count"
call assert rs~rows[1]["id"] = 1, "alice included"
call assert rs~rows[2]["id"] = 3, "mary included at BETWEEN upper bound"
call assert rs~rows[3]["id"] = 5, "nested LOWER/SUBSTR case conversion"

likeRs = sql~execute("SELECT id FROM customers WHERE email LIKE '_ob%' ORDER BY id")
call assertSuccess likeRs, "LIKE underscore"
call assert likeRs~rows~items = 1, "LIKE underscore count"
call assert likeRs~rows[1]["id"] = 4, "LIKE underscore value"

betweenRs = sql~execute("SELECT id FROM customers WHERE score BETWEEN 15 AND 25 ORDER BY id")
call assertSuccess betweenRs, "numeric BETWEEN"
call assert betweenRs~rows~items = 3, "numeric BETWEEN inclusive"
call assert betweenRs~rows[1]["id"] = 2, "numeric BETWEEN low inclusive"
call assert betweenRs~rows[3]["id"] = 4, "numeric BETWEEN high inclusive"

call assert db~version~supports("PREDICATE_FUNCTIONS"), "predicate function capability"
call assert db~version~supports("LIKE"), "LIKE capability"
call assert db~version~supports("BETWEEN"), "BETWEEN capability"

cleanup = .NoSQLServerTestSupport~removeDatabase(root)
say "NOSQLSERVER V0.15 SCALAR PREDICATE SMOKE: OK"
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
