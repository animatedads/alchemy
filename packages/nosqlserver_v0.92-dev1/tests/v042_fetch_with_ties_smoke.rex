root=.NoSQLServerTestSupport~createBlankDatabase("v042")
sql=.NoSQLServerSQL~new(.FileDatabaseEngine~new(root))

call ok sql~execute("CREATE TABLE score (id INTEGER PRIMARY KEY, name VARCHAR, points INTEGER)")
call ok sql~execute("INSERT INTO score VALUES (1,'a',100),(2,'b',90),(3,'c',80),(4,'d',80),(5,'e',70),(6,'f',NULL)")

r=sql~execute("SELECT id,name,points FROM score ORDER BY points DESC NULLS LAST FETCH FIRST 3 ROWS WITH TIES")
call assert r~status=.Error~SUCCESS, "fetch ties query"
call assert r~rows~items=4, "tie extends result"
call assert r~rows[1]["id"]=1, "first"
call assert r~rows[2]["id"]=2, "second"
call assert r~rows[3]["points"]=80, "boundary"
call assert r~rows[4]["points"]=80, "tied boundary retained"

r=sql~execute("SELECT id,points FROM score ORDER BY points DESC NULLS LAST FETCH FIRST 2 ROWS WITH TIES")
call assert r~status=.Error~SUCCESS, "fetch no tie"
call assert r~rows~items=2, "no extra rows"

r=sql~execute("SELECT id FROM score ORDER BY id FETCH FIRST 0 ROWS WITH TIES")
call assert r~status=.Error~SUCCESS, "fetch zero"
call assert r~rows~items=0, "fetch zero empty"

bad=sql~execute("SELECT id FROM score FETCH FIRST 2 ROWS WITH TIES")
call assert bad~error=.Error~SQLUNSUPPORTED, "ties requires ordering"

bad=sql~execute("SELECT id FROM score ORDER BY id LIMIT 1 FETCH FIRST 1 ROWS WITH TIES")
call assert bad~status \= .Error~SUCCESS, "limit/fetch conflict rejected"

db=.FileDatabaseEngine~new(root)
call assert db~version~product="NoSQLServer", "version product"
call assert db~version~supports("FETCH_WITH_TIES"), "FETCH capability survives newer release"
call assert db~version~supports("FETCH_WITH_TIES"), "fetch capability"
call assert db~version~supports("LIMIT_OFFSET"), "limit retained"

ignore=.NoSQLServerTestSupport~removeDatabase(root)
say "NOSQLSERVER V0.42 FETCH WITH TIES SMOKE: OK"
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
