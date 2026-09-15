root=.NoSQLServerTestSupport~createBlankDatabase("v064")
db=.FileDatabaseEngine~new(root)
sql=.NoSQLServerSQL~new(db)

call ok sql~execute("CREATE TABLE emp (emp_id INTEGER PRIMARY KEY, full_name VARCHAR, dept_id INTEGER)")
call ok sql~execute("CREATE TABLE timesheet (entry_id INTEGER PRIMARY KEY, emp_id INTEGER, hours DECIMAL, billable BOOLEAN)")
call ok sql~execute("INSERT INTO emp VALUES (2,'Grace',10),(3,'Alan',10),(4,'Katherine',10),(6,'Barbara',20),(7,'Linus',30)")
call ok sql~execute("INSERT INTO timesheet VALUES (1,3,8,TRUE),(2,3,7.5,TRUE),(3,4,6,TRUE),(4,6,8,TRUE),(5,6,8,TRUE),(6,7,3,TRUE),(7,2,2,TRUE),(8,3,4,FALSE)")

q="WITH per_emp AS (" ||,
  "SELECT t.emp_id, SUM(t.hours) AS billable_hours " ||,
  "FROM timesheet t WHERE t.billable=TRUE GROUP BY t.emp_id" ||,
  "), dept_mean AS (" ||,
  "SELECT e.dept_id, AVG(p.billable_hours) AS mean_hours " ||,
  "FROM emp e JOIN per_emp p ON p.emp_id=e.emp_id GROUP BY e.dept_id" ||,
  ") " ||,
  "SELECT e.full_name,e.dept_id,p.billable_hours,d.mean_hours " ||,
  "FROM emp e JOIN per_emp p ON p.emp_id=e.emp_id " ||,
  "JOIN dept_mean d ON d.dept_id=e.dept_id " ||,
  "WHERE p.billable_hours>d.mean_hours ORDER BY p.billable_hours DESC"

r=sql~execute(q)
call assert r~status=.Error~SUCCESS,"multi CTE status"
call assert r~rows~items=1,"one above-mean employee"
call assert r~rows[1]["e.full_name"]="Alan","employee"
call assert r~rows[1]["e.dept_id"]=10,"department"
call assert abs(r~rows[1]["p.billable_hours"]-15.5)<0.000001,"hours"
call assert abs(r~rows[1]["d.mean_hours"]-(23.5/3))<0.000001,"mean"
call assert r~accessPath~startsWith("MULTI_CTE_"),"access path"

-- CTEs are statement-local materializations, not catalog tables.
call assert db~table("per_emp")==.nil,"first CTE does not leak"
call assert db~table("dept_mean")==.nil,"second CTE does not leak"

-- Later CTEs may depend on earlier CTEs; a forward reference is not invented.
bad=sql~execute("WITH second AS (SELECT id FROM first), first AS (SELECT emp_id AS id FROM emp) SELECT id FROM second")
call assert bad~status=.Error~NOTEXECUTED,"forward reference rejected"
call assert bad~error=.Error~NOTFOUND,"forward reference reports missing table"

-- Duplicate names are rejected.
bad=sql~execute("WITH x AS (SELECT emp_id AS id FROM emp), x AS (SELECT emp_id AS id FROM emp) SELECT id FROM x")
call assert bad~error=.Error~SQLPARSEERROR,"duplicate CTE rejected"

call assert db~version~product="NoSQLServer","version product"
call assert db~version~supports("MULTI_CTE"),"capability"

ignore=.NoSQLServerTestSupport~removeDatabase(root)
say "NOSQLSERVER V0.64 MULTI CTE SMOKE: OK"
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
