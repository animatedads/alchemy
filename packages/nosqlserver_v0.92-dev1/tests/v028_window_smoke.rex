root = .NoSQLServerTestSupport~createBlankDatabase("v028-window")
db = .FileDatabaseEngine~new(root)
sql = .NoSQLServerSQL~new(db)
call ok sql~execute("CREATE TABLE timesheet (entry_id INTEGER PRIMARY KEY, emp_id INTEGER, work_date DATE, hours DECIMAL);")
call ok sql~execute("INSERT INTO timesheet (entry_id,emp_id,work_date,hours) VALUES (1,3,'2024-02-05',8.0),(2,3,'2024-02-06',7.5),(3,3,'2025-01-20',4.0),(4,4,'2024-02-05',6.0),(5,4,'2025-01-21',5.0);")
q = "SELECT t.emp_id, t.work_date, t.hours, SUM(t.hours) OVER (PARTITION BY t.emp_id ORDER BY t.work_date ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS running_hours FROM timesheet t ORDER BY t.emp_id, t.work_date;"
r = sql~execute(q)
call assert r~status=.Error~SUCCESS, "window status"
call assert r~rows~items=5, "window row count"
expectedEmp = "3 3 3 4 4"
expectedDate = "2024-02-05 2024-02-06 2025-01-20 2024-02-05 2025-01-21"
expectedRun = "8.0 15.5 19.5 6.0 11.0"
do i=1 to 5
  row=r~rows[i]
  call assert row["t.emp_id"] = expectedEmp~word(i), "emp order" i
  call assert row["t.work_date"] = expectedDate~word(i), "date order" i
  call assert row["running_hours"] = expectedRun~word(i), "running total" i
end
call assert r~accessPath="WINDOW_RUNNING_SCAN", "window access path"
call assert db~version~supports("WINDOW_RUNNING_AGGREGATE"), "window capability"
x=.NoSQLServerTestSupport~removeDatabase(root)
say "NOSQLSERVER V0.28 WINDOW SMOKE: OK"
exit 0
ok: procedure
 use arg r
 call assert r~status=.Error~SUCCESS, "setup SQL"
 return
assert: procedure
 use arg condition, message
 if \condition then do; say "ASSERT FAILED:" message; exit 1; end
 return
::requires "TestSupport.cls"
::requires "../src/NoSQLServer.cls"
