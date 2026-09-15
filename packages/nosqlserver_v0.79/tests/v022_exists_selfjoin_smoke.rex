parse arg ignored
root = .NoSQLServerTestSupport~createBlankDatabase("v022_exists")
engine = .FileDatabaseEngine~new(root)
sql = .NoSQLServerSQL~new(engine)
call assertSuccess sql~execute("CREATE TABLE emp (emp_id INTEGER PRIMARY KEY, full_name VARCHAR NOT NULL, manager_id INTEGER, salary DECIMAL NOT NULL)")
call assertSuccess sql~execute("CREATE TABLE timesheet (entry_id INTEGER PRIMARY KEY, emp_id INTEGER NOT NULL, hours DECIMAL NOT NULL)")
call assertSuccess sql~execute("INSERT INTO emp (emp_id,full_name,manager_id,salary) VALUES (1,'Boss',NULL,100),(2,'Worker',1,60),(3,'Idle',1,50)")
call assertSuccess sql~execute("INSERT INTO timesheet (entry_id,emp_id,hours) VALUES (1,2,8),(2,2,7)")

rs = sql~execute("SELECT e.emp_id,e.full_name FROM emp e WHERE NOT EXISTS (SELECT 1 FROM timesheet t WHERE t.emp_id=e.emp_id) ORDER BY e.emp_id")
call assertSuccess rs
call assert rs~rows~items = 2, "NOT EXISTS count"
call assert rs~rows[1]["e.emp_id"] = 1, "Boss has no timesheet"
call assert rs~rows[2]["e.emp_id"] = 3, "Idle has no timesheet"
call assert rs~accessPath = "NOT_EXISTS_CORRELATED", "NOT EXISTS path"

rs = sql~execute("SELECT e.emp_id FROM emp e WHERE EXISTS (SELECT 1 FROM timesheet t WHERE t.emp_id=e.emp_id GROUP BY t.emp_id HAVING SUM(t.hours)>10) ORDER BY e.emp_id")
call assertSuccess rs
call assert rs~rows~items = 1, "EXISTS aggregate count"
call assert rs~rows[1]["e.emp_id"] = 2, "aggregate EXISTS worker"
call assert rs~accessPath = "EXISTS_CORRELATED", "EXISTS path"

rs = sql~execute("SELECT e.full_name AS employee,m.full_name AS manager,e.salary AS emp_sal,m.salary AS mgr_sal FROM emp e JOIN emp m ON m.emp_id=e.manager_id WHERE e.salary<m.salary ORDER BY e.emp_id")
call assertSuccess rs
call assert rs~rows~items = 2, "self join count"
call assert rs~rows[1]["employee"] = "Worker", "self join worker"
call assert rs~rows[1]["manager"] = "Boss", "worker manager"
call assert rs~rows[2]["employee"] = "Idle", "self join idle"
call assert rs~rows[2]["manager"] = "Boss", "idle manager"
call assert rs~accessPath = "INNER_HASH_CHAIN", "alias-safe self join path"

v = engine~version
call assert datatype(v~release, "N"), "numeric release contract"
call assert v~supports("EXISTS_SUBQUERY"), "EXISTS capability"
call assert v~supports("NOT_EXISTS_SUBQUERY"), "NOT EXISTS capability"
cleanup = .NoSQLServerTestSupport~removeDatabase(root)
say "NOSQLSERVER V0.22 EXISTS/SELF-JOIN HARDENING SMOKE: OK"
exit 0

assertSuccess: procedure
 use arg rs
 if rs~status \= .Error~SUCCESS then do; say "ASSERT FAILED: expected success" rs~error rs~message; exit 1; end
 return
assert: procedure
 use arg condition,message
 if \condition then do; say "ASSERT FAILED:" message; exit 1; end
 return
::requires "../src/NoSQLServer.cls"
::requires "TestSupport.cls"
