root=.NoSQLServerTestSupport~createBlankDatabase("v042")
sql=.NoSQLServerSQL~new(.FileDatabaseEngine~new(root))

call ok sql~execute("CREATE TABLE customer (id INTEGER PRIMARY KEY, name VARCHAR, grp INTEGER)")
call ok sql~execute("CREATE TABLE ord (oid INTEGER PRIMARY KEY, customer_id INTEGER, amount INTEGER)")
call ok sql~execute("INSERT INTO customer VALUES (1,'a',1),(2,'b',1),(3,'c',2),(4,'d',2)")
call ok sql~execute("INSERT INTO ord VALUES (10,1,5),(11,1,7),(12,2,3),(13,3,9),(14,4,1)")

r=sql~execute("SELECT c.id,c.name,o.amount FROM customer c JOIN ord o ON c.id=o.customer_id ORDER BY o.amount DESC LIMIT 2")
call assert r~status=.Error~SUCCESS, "join limit"
call assert r~rows~items=2, "join limit count"
call assert r~rows[1]["o.amount"]=9, "join first"
call assert r~rows[2]["o.amount"]=7, "join second"

r=sql~execute("SELECT c.grp,COUNT(*) AS n,SUM(o.amount) AS total FROM customer c JOIN ord o ON c.id=o.customer_id GROUP BY c.grp ORDER BY total DESC LIMIT 1")
call assert r~status=.Error~SUCCESS, "aggregate limit"
call assert r~rows~items=1, "aggregate limit count"
call assert r~rows[1]["c.grp"]=1, "aggregate winner grp"
call assert r~rows[1]["total"]=15, "aggregate winner total"

r=sql~execute("SELECT id,name FROM (SELECT id,name FROM customer ORDER BY id DESC) x ORDER BY id LIMIT 2 OFFSET 1")
call assert r~status=.Error~SUCCESS, "derived limit offset"
call assert r~rows~items=2, "derived count"
call assert r~rows[1]["id"]=2, "derived first"
call assert r~rows[2]["id"]=3, "derived second"

r=sql~execute("SELECT id FROM customer WHERE grp=1 UNION SELECT id FROM customer WHERE grp=2 ORDER BY id DESC LIMIT 2")
call assert r~status=.Error~SUCCESS, "union limit"
call assert r~rows~items=2, "union count"
call assert r~rows[1]["id"]=4, "union first"
call assert r~rows[2]["id"]=3, "union second"

r=sql~execute("SELECT id,ROW_NUMBER() OVER (ORDER BY id DESC) AS rn FROM customer ORDER BY id DESC LIMIT 2")
call assert r~status=.Error~SUCCESS, "window limit"
call assert r~rows~items=2, "window count"
call assert r~rows[1]["id"]=4, "window first"
call assert r~rows[1]["rn"]=1, "window rn1"
call assert r~rows[2]["id"]=3, "window second"
call assert r~rows[2]["rn"]=2, "window rn2"

r=sql~execute("SELECT id FROM customer ORDER BY id LIMIT 1,2")
call assert r~status=.Error~SUCCESS, "mysql comma limit"
call assert r~rows~items=2, "mysql comma count"
call assert r~rows[1]["id"]=2, "mysql comma first"
call assert r~rows[2]["id"]=3, "mysql comma second"

ignore=.NoSQLServerTestSupport~removeDatabase(root)
say "NOSQLSERVER V0.42 LIMIT COMPOSITION SMOKE: OK"
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
