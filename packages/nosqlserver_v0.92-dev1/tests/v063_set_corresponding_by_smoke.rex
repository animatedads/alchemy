root=.NoSQLServerTestSupport~createBlankDatabase("v063")
db=.FileDatabaseEngine~new(root)
sql=.NoSQLServerSQL~new(db)

call ok sql~execute("CREATE TABLE emp (emp_id INTEGER PRIMARY KEY, full_name VARCHAR, dept_id INTEGER, manager_id INTEGER)")
call ok sql~execute("INSERT INTO emp VALUES (1,'Ada',10,NULL),(2,'Grace',10,1),(3,'Alan',10,2),(4,'Katherine',10,2),(5,'Dennis',20,1),(6,'Barbara',20,5),(7,'Linus',30,1),(8,'Margaret',40,1),(9,'Ken',10,2),(10,'Desk',30,7)")

q="SELECT emp_id AS id, full_name AS name FROM emp WHERE dept_id=10 " ||,
  "EXCEPT CORRESPONDING BY (id) " ||,
  "SELECT manager_id AS id, full_name AS name FROM emp WHERE manager_id IS NOT NULL " ||,
  "ORDER BY id"

r=sql~execute(q)
call assert r~status=.Error~SUCCESS,"EXCEPT CORRESPONDING BY status"
call assert r~rows~items=3,"three rows"
ids="3 4 9"~makeArray(" ")
do i=1 to 3
  call assert r~rows[i]["id"]=ids[i],"id" i
  call assert r~rows[i]~values~allIndexes~items=1,"only BY column projected" i
end
call assert r~accessPath="SET_EXCEPT_CORRESPONDING","path"

-- BY names must exist in both projected branches.
bad=sql~execute("SELECT emp_id AS id FROM emp EXCEPT CORRESPONDING BY (name) SELECT manager_id AS id FROM emp")
call assert bad~error=.Error~SQLPARSEERROR,"missing BY name rejected"

-- Duplicate BY names are invalid rather than silently deduplicated.
bad=sql~execute("SELECT emp_id AS id FROM emp EXCEPT CORRESPONDING BY (id,id) SELECT manager_id AS id FROM emp")
call assert bad~error=.Error~SQLPARSEERROR,"duplicate BY name rejected"

call assert db~version~product="NoSQLServer","version product"
call assert db~version~supports("SET_CORRESPONDING_BY"),"capability"

ignore=.NoSQLServerTestSupport~removeDatabase(root)
say "NOSQLSERVER V0.63 SET CORRESPONDING BY SMOKE: OK"
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
