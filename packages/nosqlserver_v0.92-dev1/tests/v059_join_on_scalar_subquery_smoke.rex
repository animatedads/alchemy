root=.NoSQLServerTestSupport~createBlankDatabase("v059")
sql=.NoSQLServerSQL~new(.FileDatabaseEngine~new(root))

call ok sql~execute("CREATE TABLE emp (emp_id INTEGER PRIMARY KEY, full_name VARCHAR)")
call ok sql~execute("CREATE TABLE project (project_id INTEGER PRIMARY KEY, title VARCHAR, dept_id INTEGER, budget DECIMAL)")
call ok sql~execute("CREATE TABLE assignment (assignment_id INTEGER PRIMARY KEY, emp_id INTEGER, project_id INTEGER, role VARCHAR)")

call ok sql~execute("INSERT INTO emp VALUES (1,'Ada'),(2,'Alan'),(3,'Grace'),(4,'Katherine'),(5,'Dennis')")
call ok sql~execute("INSERT INTO project VALUES (100,'Hyperdrive',10,500000),(104,'Skunkworks',10,25000),(101,'Quantum',20,320000)")
call ok sql~execute("INSERT INTO assignment VALUES (1,1,100,'Sponsor'),(2,2,100,'Engineer'),(3,3,100,'Lead'),(4,4,100,'Engineer'),(5,5,101,'Lead')")

q="SELECT e.full_name,p.title,a.role " ||,
  "FROM emp e " ||,
  "JOIN assignment a ON a.emp_id=e.emp_id " ||,
  "JOIN project p ON p.project_id=a.project_id " ||,
  "AND p.budget > (SELECT AVG(budget) FROM project p2 WHERE p2.dept_id=p.dept_id) " ||,
  "ORDER BY e.full_name"

r=sql~execute(q)
call assert r~status=.Error~SUCCESS,"join-on scalar subquery"
call assert r~rows~items=4,"four qualifying rows"
names="Ada Alan Grace Katherine"~makeArray(" ")
roles="Sponsor Engineer Lead Engineer"~makeArray(" ")
do i=1 to 4
  call assert r~rows[i]["e.full_name"]=names[i],"name" i
  call assert r~rows[i]["p.title"]="Hyperdrive","title" i
  call assert r~rows[i]["a.role"]=roles[i],"role" i
end
call assert r~accessPath="INNER_HASH_CHAIN","join path"

db=.FileDatabaseEngine~new(root)
call assert db~version~product="NoSQLServer","version product"
call assert db~version~supports("JOIN_ON_SCALAR_SUBQUERY"),"v0.59 capability survives"
call assert db~version~supports("JOIN_ON_SCALAR_SUBQUERY"),"capability"

ignore=.NoSQLServerTestSupport~removeDatabase(root)
say "NOSQLSERVER V0.59 JOIN ON SCALAR SUBQUERY SMOKE: OK"
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
