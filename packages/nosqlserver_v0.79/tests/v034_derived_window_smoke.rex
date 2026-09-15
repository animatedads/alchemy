root = .NoSQLServerTestSupport~createBlankDatabase("v034")
engine = .FileDatabaseEngine~new(root)
sql = .NoSQLServerSQL~new(engine)
call must sql~execute("CREATE TABLE timesheet (entry_id INTEGER PRIMARY KEY, emp_id INTEGER, hours DECIMAL)")
call must sql~execute("INSERT INTO timesheet (entry_id,emp_id,hours) VALUES (1,3,8),(2,3,7.5),(3,3,4),(4,6,8),(5,6,8),(6,4,11)")
q = "SELECT x.emp_id, x.total_hours, RANK() OVER (ORDER BY x.total_hours DESC) AS hours_rank FROM (SELECT emp_id, SUM(hours) AS total_hours FROM timesheet GROUP BY emp_id) x ORDER BY hours_rank, x.emp_id"
rs = sql~execute(q)
call must rs
call assert rs~rows~items = 3, "row count"
call assert rs~rows[1]["x.emp_id"] = 3 & rs~rows[1]["hours_rank"] = 1, "rank 1"
call assert rs~rows[2]["x.emp_id"] = 6 & rs~rows[2]["hours_rank"] = 2, "rank 2"
call assert rs~rows[3]["x.emp_id"] = 4 & rs~rows[3]["hours_rank"] = 3, "rank 3"
call assert engine~version~product = "NoSQLServer", "version product"
call assert engine~version~supports("WINDOW_RANK"), "window capability survives newer release"
cleanup=.NoSQLServerTestSupport~removeDatabase(root)
say "NOSQLSERVER V0.34 DERIVED WINDOW SMOKE: OK"
exit 0

must: procedure
 use arg rs
 if rs~status \= .Error~SUCCESS then do; say "FAILED:" rs~error rs~message; exit 1; end
 return
assert: procedure
 use arg ok,msg
 if \ok then do; say "ASSERT FAILED:" msg; exit 1; end
 return
::requires "../src/NoSQLServer.cls"
::requires "TestSupport.cls"
