root = .NoSQLServerTestSupport~createBlankDatabase("v027")
db = .FileDatabaseEngine~new(root)
sql = .NoSQLServerSQL~new(db)
call ok sql~execute("CREATE TABLE emp (id INTEGER PRIMARY KEY, dept INTEGER, salary DECIMAL, active BOOLEAN, hired DATE);")
call ok sql~execute("CREATE TABLE log (id INTEGER PRIMARY KEY, emp INTEGER, billable BOOLEAN);")
call ok sql~execute("INSERT INTO emp (id,dept,salary,active,hired) VALUES (1,10,100,TRUE,'2018-01-01'),(2,10,40,TRUE,'2024-01-01'),(3,10,0,FALSE,'2019-01-01');")
call ok sql~execute("INSERT INTO log (id,emp,billable) VALUES (1,1,FALSE),(2,3,FALSE);")
r = sql~execute("UPDATE emp SET salary = salary * 1.10 WHERE active = TRUE AND salary < (SELECT AVG(salary) FROM emp e2 WHERE e2.dept = emp.dept);")
call assert r~status=.Error~SUCCESS & r~affectedRows=1, "correlated expression update"
r = sql~execute("DELETE FROM log WHERE billable = FALSE AND emp IN (SELECT id FROM emp WHERE active = FALSE);")
call assert r~status=.Error~SUCCESS & r~affectedRows=1, "subquery delete"
r = sql~execute("SELECT id FROM emp WHERE CAST(hired AS VARCHAR) LIKE '201%';")
call assert r~status=.Error~SUCCESS & r~rows~items=2, "cast varchar predicate"
call assert db~version~supports("CORRELATED_UPDATE"), "version correlated update"
call assert db~version~supports("SUBQUERY_DELETE"), "version subquery delete"
call assert db~version~supports("CAST_VARCHAR"), "version cast"
x=.NoSQLServerTestSupport~removeDatabase(root)
say "NOSQLSERVER V0.27 MUTATION/CAST SMOKE: OK"
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
