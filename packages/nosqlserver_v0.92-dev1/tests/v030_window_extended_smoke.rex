root = .NoSQLServerTestSupport~createBlankDatabase("v030-window")
db = .FileDatabaseEngine~new(root)
sql = .NoSQLServerSQL~new(db)
call ok sql~execute("CREATE TABLE pay (id INTEGER PRIMARY KEY, dept INTEGER, name VARCHAR, salary DECIMAL);")
call ok sql~execute("INSERT INTO pay (id,dept,name,salary) VALUES (1,10,'Ada',100),(2,10,'Bob',100),(3,10,'Cid',80),(4,20,'Dee',90),(5,20,'Eve',70);")
q = "SELECT p.dept, p.name, p.salary, " || -
    "ROW_NUMBER() OVER (PARTITION BY p.dept ORDER BY p.salary DESC) AS rn, " || -
    "RANK() OVER (PARTITION BY p.dept ORDER BY p.salary DESC) AS rnk, " || -
    "DENSE_RANK() OVER (PARTITION BY p.dept ORDER BY p.salary DESC) AS drnk, " || -
    "COUNT(*) OVER (PARTITION BY p.dept ORDER BY p.salary DESC ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS cnt, " || -
    "AVG(p.salary) OVER (PARTITION BY p.dept ORDER BY p.salary DESC ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS avgv, " || -
    "MIN(p.salary) OVER (PARTITION BY p.dept ORDER BY p.salary DESC ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS minv, " || -
    "MAX(p.salary) OVER (PARTITION BY p.dept ORDER BY p.salary DESC ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS maxv " || -
    "FROM pay p ORDER BY p.dept, p.salary DESC;"
r = sql~execute(q)
call assert r~status=.Error~SUCCESS, "extended window status" r~error
call assert r~rows~items=5, "extended row count"
-- dept 10: stable peer order Ada/Bob then Cid.
call check r~rows[1], 10, "Ada", 1, 1, 1, 1, 100, 100, 100
call check r~rows[2], 10, "Bob", 2, 1, 1, 2, 100, 100, 100
call check r~rows[3], 10, "Cid", 3, 3, 2, 3, 93.3333333333333333, 80, 100
-- partition reset.
call check r~rows[4], 20, "Dee", 1, 1, 1, 1, 90, 90, 90
call check r~rows[5], 20, "Eve", 2, 2, 2, 2, 80, 70, 90
call assert db~version~supports("WINDOW_ROW_NUMBER"), "row_number capability"
call assert db~version~supports("WINDOW_RANK"), "rank capability"
call assert db~version~supports("WINDOW_DENSE_RANK"), "dense rank capability"
call assert db~version~supports("WINDOW_RUNNING_COUNT"), "count capability"
call assert db~version~supports("WINDOW_RUNNING_AVG"), "avg capability"
call assert db~version~release \= "", "version release available"
-- no PARTITION BY is also supported for ranking.
r2 = sql~execute("SELECT p.name, ROW_NUMBER() OVER (ORDER BY p.salary DESC) AS rn FROM pay p ORDER BY rn;")
call assert r2~status=.Error~SUCCESS, "global row_number status" r2~error
call assert r2~rows~items=5, "global row_number row count"
call assert r2~rows[1]["rn"] = 1, "global rn 1"
call assert r2~rows[5]["rn"] = 5, "global rn 5"
x=.NoSQLServerTestSupport~removeDatabase(root)
say "NOSQLSERVER V0.30 EXTENDED WINDOW SMOKE: OK"
exit 0

check: procedure
  use arg row, dept, name, rn, rnk, drnk, cnt, avgv, minv, maxv
  call assert row["p.dept"] = dept, "dept"
  call assert row["p.name"] = name, "name"
  call assert row["rn"] = rn, "row_number" name
  call assert row["rnk"] = rnk, "rank" name
  call assert row["drnk"] = drnk, "dense_rank" name
  call assert row["cnt"] = cnt, "running count" name
  call assert abs(row["avgv"] - avgv) < 0.0000001, "running avg" name
  call assert row["minv"] = minv, "running min" name
  call assert row["maxv"] = maxv, "running max" name
  return
ok: procedure
  use arg r
  call assert r~status=.Error~SUCCESS, "setup SQL" r~error
  return
assert: procedure
  use arg condition, message
  if \condition then do; say "ASSERT FAILED:" message; exit 1; end
  return
::requires "TestSupport.cls"
::requires "../src/NoSQLServer.cls"
