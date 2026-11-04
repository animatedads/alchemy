root=.NoSQLServerTestSupport~createBlankDatabase("v041")
sql=.NoSQLServerSQL~new(.FileDatabaseEngine~new(root))

call ok sql~execute("CREATE TABLE customer (customer_id INTEGER PRIMARY KEY, name VARCHAR, email VARCHAR)")
call ok sql~execute("INSERT INTO customer VALUES (101,'a','a@x'),(106,'b','b@x'),(107,'c','c@x'),(108,'d','d@x'),(109,'e','e@x')")

r=sql~execute("SELECT * FROM customer ORDER BY customer_id DESC LIMIT 1")
call assert r~status=.Error~SUCCESS, "ORDER BY LIMIT"
call assert r~rows~items=1, "one limited row"
call assert r~rows[1]["customer_id"]=109, "limit happens after descending order"

r=sql~execute("SELECT customer_id FROM customer ORDER BY customer_id LIMIT 2 OFFSET 1")
call assert r~status=.Error~SUCCESS, "LIMIT OFFSET"
call assert r~rows~items=2, "two rows"
call assert r~rows[1]["customer_id"]=106, "offset first"
call assert r~rows[2]["customer_id"]=107, "offset second"

r=sql~execute("SELECT customer_id FROM customer ORDER BY customer_id LIMIT 2,2")
call assert r~status=.Error~SUCCESS, "MySQL LIMIT offset,count"
call assert r~rows~items=2, "comma rows"
call assert r~rows[1]["customer_id"]=107, "comma first"
call assert r~rows[2]["customer_id"]=108, "comma second"

r=sql~execute("SELECT customer_id FROM customer ORDER BY customer_id LIMIT 0")
call assert r~status=.Error~SUCCESS, "LIMIT zero"
call assert r~rows~items=0, "LIMIT zero empty"

r=sql~execute("SELECT customer_id FROM customer ORDER BY customer_id LIMIT 5 OFFSET 99")
call assert r~status=.Error~SUCCESS, "offset beyond end"
call assert r~rows~items=0, "offset beyond end empty"

bad=sql~execute("SELECT * FROM customer LIMIT -1")
call assert bad~status \= .Error~SUCCESS, "negative limit rejected"
bad=sql~execute("SELECT * FROM customer LIMIT banana")
call assert bad~status \= .Error~SUCCESS, "non-numeric limit rejected"

db=.FileDatabaseEngine~new(root)
call assert db~version~product="NoSQLServer", "version product"
call assert db~version~supports("LIMIT_OFFSET"), "LIMIT capability survives newer release"
call assert db~version~supports("LIMIT_OFFSET"), "limit capability"

ignore=.NoSQLServerTestSupport~removeDatabase(root)
say "NOSQLSERVER V0.41 LIMIT/OFFSET SMOKE: OK"
exit 0

ok: procedure
  use arg rs
  call assert rs~status=.Error~SUCCESS, "setup"
  return
assert: procedure
  use arg condition,message
  if \condition then do
    say "ASSERT FAILED:" message
    exit 1
  end
  return

::requires "../src/NoSQLServer.cls"
::requires "TestSupport.cls"
