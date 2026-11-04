root = .NoSQLServerTestSupport~createBlankDatabase("v035")
sql = .NoSQLServerSQL~new(.FileDatabaseEngine~new(root))

call ok sql~execute("CREATE TABLE pay (id INTEGER PRIMARY KEY, dept INTEGER, name VARCHAR, salary DECIMAL)")
call ok sql~execute("INSERT INTO pay(id,dept,name,salary) VALUES (1,10,'A',100),(2,10,'B',80),(3,10,'C',60),(4,20,'D',90),(5,20,'E',70),(6,30,'F',50)")

q = "SELECT dept, salary, ROW_NUMBER() OVER (PARTITION BY dept ORDER BY salary) AS rn, COUNT(*) OVER (PARTITION BY dept) AS n FROM pay"
rs = sql~execute(q)
call assert rs~status = .Error~SUCCESS, "mixed ordered/partition windows"
call assert rs~rows~items = 6, "window row count"

outer = "SELECT dept, salary FROM (" || q || ") x WHERE rn = (n + 1) / 2 ORDER BY dept"
mr = sql~execute(outer)
call assert mr~status = .Error~SUCCESS, "derived arithmetic window filter"
call assert mr~rows~items = 2, "odd partitions selected"
call assert mr~rows[1]["dept"] = 10, "dept10"
call assert mr~rows[1]["salary"] = 80, "dept10 median"
call assert mr~rows[2]["dept"] = 30, "dept30"
call assert mr~rows[2]["salary"] = 50, "dept30 median"

topq = "SELECT name,salary,rk FROM (SELECT name,salary,RANK() OVER (PARTITION BY dept ORDER BY salary DESC) AS rk FROM pay) z WHERE rk = 1 ORDER BY salary DESC"
tr = sql~execute(topq)
call assert tr~status = .Error~SUCCESS, "derived rank filter"
call assert tr~rows~items = 3, "rank winners"

db = .FileDatabaseEngine~new(root)
call assert db~version~supports("WINDOW_PARTITION_AGGREGATE"), "partition window capability"
call assert db~version~supports("DERIVED_WINDOW_FILTER"), "derived filter capability"

ignore = .NoSQLServerTestSupport~removeDatabase(root)
say "NOSQLSERVER V0.35 PARTITION WINDOW SMOKE: OK"
exit 0

ok: procedure
  use arg rs
  call assert rs~status = .Error~SUCCESS, "setup statement"
  return

assert: procedure
  use arg condition, message
  if \condition then do
    say "ASSERT FAILED:" message
    exit 1
  end
  return

::requires "../src/NoSQLServer.cls"
::requires "TestSupport.cls"
