root=.NoSQLServerTestSupport~createBlankDatabase("v037")
sql=.NoSQLServerSQL~new(.FileDatabaseEngine~new(root))

call ok sql~execute("CREATE TABLE people (id INTEGER PRIMARY KEY, grp INTEGER, salary INTEGER, active BOOLEAN)")
call ok sql~execute("INSERT INTO people(id,grp,salary,active) VALUES (1,1,100,TRUE),(2,1,50,FALSE),(3,1,80,TRUE),(4,2,70,TRUE),(5,2,20,FALSE)")

q="SELECT grp,COUNT(*) AS n,COUNT(*) FILTER (WHERE salary >= 80) AS high_n,SUM(salary) FILTER (WHERE active = TRUE) AS active_pay FROM people GROUP BY grp ORDER BY grp"
r=sql~execute(q)
call assert r~status=.Error~SUCCESS, "filtered aggregate projection"
call assert r~rows~items=2, "group count"
call assert r~rows[1]["n"]=3, "grp1 n"
call assert r~rows[1]["high_n"]=2, "grp1 high"
call assert r~rows[1]["active_pay"]=180, "grp1 active sum"
call assert r~rows[2]["n"]=2, "grp2 n"
call assert r~rows[2]["high_n"]=0, "grp2 high"
call assert r~rows[2]["active_pay"]=70, "grp2 active sum"

h="SELECT grp,COUNT(*) FILTER (WHERE salary >= 80) AS high_n FROM people GROUP BY grp HAVING COUNT(*) FILTER (WHERE salary >= 80) >= 1 ORDER BY grp"
hr=sql~execute(h)
call assert hr~status=.Error~SUCCESS, "FILTER in HAVING"
call assert hr~rows~items=1, "HAVING retained group"
call assert hr~rows[1]["grp"]=1, "HAVING group identity"
call assert hr~rows[1]["high_n"]=2, "HAVING aggregate value"

db=.FileDatabaseEngine~new(root)
call assert db~version~product="NoSQLServer", "version product"
call assert db~version~supports("AGGREGATE_FILTER"), "aggregate filter capability survives newer release"
call assert db~version~supports("AGGREGATE_FILTER"), "filter capability"

ignore=.NoSQLServerTestSupport~removeDatabase(root)
say "NOSQLSERVER V0.37 AGGREGATE FILTER SMOKE: OK"
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
