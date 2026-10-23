root = .NoSQLServerTestSupport~createBlankDatabase("v026set")
engine = .FileDatabaseEngine~new(root)
sql = .NoSQLServerSQL~new(engine)
call assertSuccess sql~execute("CREATE TABLE a (id INTEGER PRIMARY KEY, k INTEGER);"), "create a"
call assertSuccess sql~execute("CREATE TABLE b (id INTEGER PRIMARY KEY, k INTEGER);"), "create b"
call assertSuccess sql~execute("INSERT INTO a (id,k) VALUES (1,10),(2,20),(3,30),(4,40);"), "insert a"
call assertSuccess sql~execute("INSERT INTO b (id,k) VALUES (2,20),(3,30),(5,50);"), "insert b"

ri = sql~execute("SELECT id FROM a INTERSECT SELECT id FROM b ORDER BY 1;")
call assertSuccess ri, "intersect"
call assertEq ri~accessPath, "SET_INTERSECT", "intersect path"
call assertEq ri~rows~items, 2, "intersect count"
call assertEq ri~rows[1]["id"], 2, "intersect first"
call assertEq ri~rows[2]["id"], 3, "intersect second"

re = sql~execute("SELECT id FROM a EXCEPT SELECT id FROM b ORDER BY 1;")
call assertSuccess re, "except"
call assertEq re~accessPath, "SET_EXCEPT", "except path"
call assertEq re~rows~items, 2, "except count"
call assertEq re~rows[1]["id"], 1, "except first"
call assertEq re~rows[2]["id"], 4, "except second"

call assertTrue engine~version~supports("INTERSECT"), "intersect capability"
call assertTrue engine~version~supports("EXCEPT"), "except capability"
cleanup = .NoSQLServerTestSupport~removeDatabase(root)
say "NOSQLSERVER V0.26 SET OPERATOR SMOKE: OK"
exit 0
assertSuccess: procedure
  use arg rs, label
  if rs~status \= .Error~SUCCESS then do
    say "ASSERT FAILED:" label "status=" rs~status "error=" rs~error "message=" rs~message
    exit 1
  end
  return
assertEq: procedure
  use arg actual, expected, label
  if actual \= expected then do
    say "ASSERT FAILED:" label "expected=" expected "actual=" actual
    exit 1
  end
  return
assertTrue: procedure
  use arg condition, label
  if \condition then do
    say "ASSERT FAILED:" label
    exit 1
  end
  return
::requires "../src/NoSQLServer.cls"
::requires "TestSupport.cls"
