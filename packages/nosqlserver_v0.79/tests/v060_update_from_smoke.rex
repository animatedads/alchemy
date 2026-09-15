root=.NoSQLServerTestSupport~createBlankDatabase("v060")
db=.FileDatabaseEngine~new(root)
sql=.NoSQLServerSQL~new(db)

call ok sql~execute("CREATE TABLE dept (dept_id INTEGER PRIMARY KEY, location VARCHAR)")
call ok sql~execute("CREATE TABLE emp (emp_id INTEGER PRIMARY KEY, dept_id INTEGER, salary DECIMAL, active BOOLEAN)")
call ok sql~execute("INSERT INTO dept VALUES (10,'Glasgow'),(20,'Edinburgh')")
call ok sql~execute("INSERT INTO emp VALUES (1,10,120000,TRUE),(2,10,95000,TRUE),(3,10,72000,TRUE),(4,10,71000,TRUE),(5,20,88000,TRUE),(9,10,0,FALSE)")

r=sql~execute("UPDATE emp e SET salary = salary * 1.10 FROM dept d WHERE d.dept_id=e.dept_id AND d.location='Glasgow' AND e.active=TRUE")
call assert r~status=.Error~SUCCESS,"UPDATE FROM status"
call assert r~affectedRows=4,"four rows affected"
call assert r~accessPath="UPDATE_FROM_NESTED_LOOP","access path"

q=sql~execute("SELECT emp_id,salary FROM emp ORDER BY emp_id")
call ok q
ids="1 2 3 4 5 9"~makeArray(" ")
salaries="132000 104500 79200 78100 88000 0"~makeArray(" ")
do i=1 to ids~items
  call assert q~rows[i]["emp_id"]=ids[i],"id" i
  call assert abs(q~rows[i]["salary"]-salaries[i])<0.000001,"salary" i
end

-- A target row with multiple FROM matches must be rejected, not chosen arbitrarily.
call ok sql~execute("CREATE TABLE dupdept (id INTEGER PRIMARY KEY, dept_id INTEGER)")
call ok sql~execute("INSERT INTO dupdept VALUES (1,10),(2,10)")
bad=sql~execute("UPDATE emp e SET salary=salary+1 FROM dupdept d WHERE d.dept_id=e.dept_id AND e.emp_id=1")
call assert bad~error=.Error~SQLUNSUPPORTED,"multiple source matches rejected"
q=sql~execute("SELECT salary FROM emp WHERE emp_id=1")
call ok q
call assert q~rows[1]["salary"]=132000,"rejected multi-match does not mutate"

call assert db~version~product="NoSQLServer","version product"
call assert db~version~supports("UPDATE_FROM"),"v0.60 capability survives"
call assert db~version~supports("UPDATE_FROM"),"capability"

ignore=.NoSQLServerTestSupport~removeDatabase(root)
say "NOSQLSERVER V0.60 UPDATE FROM SMOKE: OK"
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
