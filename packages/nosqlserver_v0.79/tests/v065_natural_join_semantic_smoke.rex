root=.NoSQLServerTestSupport~createBlankDatabase("v065")
db=.FileDatabaseEngine~new(root)
sql=.NoSQLServerSQL~new(db)

call ok sql~execute("CREATE TABLE emp (emp_id INTEGER PRIMARY KEY, full_name VARCHAR, dept_id INTEGER)")
call ok sql~execute("CREATE TABLE assignment (assignment_id INTEGER PRIMARY KEY, emp_id INTEGER, role VARCHAR)")
call ok sql~execute("INSERT INTO emp VALUES (1,'Ada',10),(2,'Grace',10),(3,'Alan',10),(4,'No Assignment',20)")
call ok sql~execute("INSERT INTO assignment VALUES (10,1,'Sponsor'),(11,2,'Lead'),(12,3,'Engineer'),(13,3,'Reviewer')")

r=sql~execute("SELECT * FROM emp NATURAL JOIN assignment ORDER BY emp_id,assignment_id")
call assert r~status=.Error~SUCCESS,"natural join status"
call assert r~accessPath="NATURAL_HASH_JOIN","natural path"
call assert r~rows~items=4,"natural row count"
ids="10 11 12 13"~makeArray(" ")
empids="1 2 3 3"~makeArray(" ")
do i=1 to 4
  call assert r~rows[i]["assignment_id"]=ids[i],"assignment" i
  call assert r~rows[i]["emp_id"]=empids[i],"emp" i
  call assert r~rows[i]~values~allIndexes~items=5,"common column emitted once" i
end

-- NULL never matches NULL in a natural-key comparison.
call ok sql~execute("CREATE TABLE lefty (id INTEGER PRIMARY KEY, common VARCHAR)")
call ok sql~execute("CREATE TABLE righty (rid INTEGER PRIMARY KEY, common VARCHAR)")
call ok sql~execute("INSERT INTO lefty VALUES (1,NULL),(2,'x')")
call ok sql~execute("INSERT INTO righty VALUES (10,NULL),(20,'x')")
r=sql~execute("SELECT * FROM lefty NATURAL JOIN righty")
call assert r~status=.Error~SUCCESS,"natural null status"
call assert r~rows~items=1,"NULL natural keys do not match"
call assert r~rows[1]["id"]=2,"nonnull left"
call assert r~rows[1]["rid"]=20,"nonnull right"

-- No common columns degenerates to a cross join, as NATURAL JOIN specifies.
call ok sql~execute("CREATE TABLE a (a_id INTEGER PRIMARY KEY)")
call ok sql~execute("CREATE TABLE b (b_id INTEGER PRIMARY KEY)")
call ok sql~execute("INSERT INTO a VALUES (1),(2)")
call ok sql~execute("INSERT INTO b VALUES (10),(20),(30)")
r=sql~execute("SELECT * FROM a NATURAL JOIN b")
call assert r~status=.Error~SUCCESS,"natural cross status"
call assert r~accessPath="NATURAL_CROSS_SCAN","natural cross path"
call assert r~rows~items=6,"natural cross count"

-- Q23 semantic lock: DISTINCT is not implicit GROUP BY.
bad=sql~execute("SELECT DISTINCT emp_id FROM emp ORDER BY AVG(dept_id)")
call assert bad~error=.Error~SQLPARSEERROR,"distinct aggregate order rejected"
call assert bad~message~pos("explicit GROUP BY")>0,"distinct rejection diagnostic"

call assert db~version~product="NoSQLServer","version product"
call assert db~version~supports("NATURAL_JOIN"),"capability"

ignore=.NoSQLServerTestSupport~removeDatabase(root)
say "NOSQLSERVER V0.65 NATURAL JOIN / DISTINCT SEMANTIC SMOKE: OK"
exit 0

ok: procedure
  use arg rs
  call assert rs~status=.Error~SUCCESS,"setup"
  return

assert: procedure
  use arg condition,message,detail=""
  if \condition then do
    say "ASSERT FAILED:" message detail
    exit 1
  end
  return

::requires "../src/NoSQLServer.cls"
::requires "TestSupport.cls"
