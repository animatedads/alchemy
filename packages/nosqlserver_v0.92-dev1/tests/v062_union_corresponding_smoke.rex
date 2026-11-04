root=.NoSQLServerTestSupport~createBlankDatabase("v062u")
db=.FileDatabaseEngine~new(root)
sql=.NoSQLServerSQL~new(db)
call ok sql~execute("CREATE TABLE emp (emp_id INTEGER PRIMARY KEY, full_name VARCHAR, dept_id INTEGER, salary DECIMAL)")
call ok sql~execute("INSERT INTO emp VALUES (1,'Ada',10,120000),(2,'Grace',10,95000),(3,'Alan',10,72000),(4,'Katherine',10,71000),(5,'Dennis',20,88000),(9,'Ken',10,0)")
q="SELECT emp_id,full_name FROM emp WHERE dept_id=10 UNION CORRESPONDING SELECT emp_id,full_name FROM emp WHERE salary>90000 ORDER BY emp_id"
r=sql~execute(q)
call assert r~status=.Error~SUCCESS,"status"
call assert r~rows~items=5,"row count"
ids="1 2 3 4 9"~makeArray(" ")
do i=1 to 5
  call assert r~rows[i]["emp_id"]=ids[i],"id" i
end
call assert r~accessPath="UNION_CORRESPONDING","path"
call assert db~version~product="NoSQLServer","version product"
call assert db~version~supports("UNION_CORRESPONDING"),"capability"
ignore=.NoSQLServerTestSupport~removeDatabase(root)
say "NOSQLSERVER V0.62 UNION CORRESPONDING SMOKE: OK"
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
