root=.NoSQLServerTestSupport~createBlankDatabase("v061")
db=.FileDatabaseEngine~new(root)
sql=.NoSQLServerSQL~new(db)

call ok sql~execute("CREATE TABLE emp (emp_id INTEGER PRIMARY KEY, active BOOLEAN)")
call ok sql~execute("CREATE TABLE timesheet (entry_id INTEGER PRIMARY KEY, emp_id INTEGER, hours DECIMAL, billable BOOLEAN)")
call ok sql~execute("INSERT INTO emp VALUES (1,TRUE),(2,FALSE),(3,FALSE)")
call ok sql~execute("INSERT INTO timesheet VALUES (10,1,8,TRUE),(11,2,4,FALSE),(12,2,6,TRUE),(13,3,5,FALSE)")

r=sql~execute("DELETE FROM timesheet t USING emp e WHERE t.emp_id=e.emp_id AND e.active=FALSE AND t.billable=FALSE")
call assert r~status=.Error~SUCCESS,"DELETE USING status"
call assert r~affectedRows=2,"two target rows deleted"
call assert r~accessPath="DELETE_USING_NESTED_LOOP","access path"

q=sql~execute("SELECT entry_id,emp_id,billable FROM timesheet ORDER BY entry_id")
call ok q
call assert q~rows~items=2,"two survivors"
call assert q~rows[1]["entry_id"]=10,"active employee row survives"
call assert q~rows[2]["entry_id"]=12,"billable inactive row survives"

-- Duplicate source matches must still delete one target only once.
call ok sql~execute("CREATE TABLE marker (marker_id INTEGER PRIMARY KEY, emp_id INTEGER)")
call ok sql~execute("INSERT INTO marker VALUES (1,2),(2,2),(3,99)")
call ok sql~execute("INSERT INTO timesheet VALUES (20,2,1,FALSE)")
r=sql~execute("DELETE FROM timesheet t USING marker m WHERE t.emp_id=m.emp_id AND t.entry_id=20")
call assert r~status=.Error~SUCCESS,"duplicate source DELETE USING"
call assert r~affectedRows=1,"duplicate source does not inflate affected count"
q=sql~execute("SELECT COUNT(*) AS n FROM timesheet WHERE entry_id=20")
call ok q
call assert q~rows[1]["n"]=0,"duplicate-source target actually deleted"

-- Non-matching USING rows do nothing.
r=sql~execute("DELETE FROM timesheet t USING marker m WHERE t.emp_id=m.emp_id AND t.entry_id=10")
call assert r~status=.Error~SUCCESS,"nonmatch status"
call assert r~affectedRows=0,"nonmatch count"
q=sql~execute("SELECT COUNT(*) AS n FROM timesheet WHERE entry_id=10")
call ok q
call assert q~rows[1]["n"]=1,"nonmatch preserves target"

call assert db~version~product="NoSQLServer","version product"
call assert db~version~supports("DELETE_USING"),"v0.61 capability survives"
call assert db~version~supports("DELETE_USING"),"capability"

ignore=.NoSQLServerTestSupport~removeDatabase(root)
say "NOSQLSERVER V0.61 DELETE USING SMOKE: OK"
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
