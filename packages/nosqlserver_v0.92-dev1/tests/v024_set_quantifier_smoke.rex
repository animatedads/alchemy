root = .NoSQLServerTestSupport~createBlankDatabase("v024")
engine = .FileDatabaseEngine~new(root)
sql = .NoSQLServerSQL~new(engine)

call ok sql~execute("CREATE TABLE pair_src (id INTEGER PRIMARY KEY, a INTEGER, b INTEGER)")
call ok sql~execute("CREATE TABLE pair_ref (id INTEGER PRIMARY KEY, a INTEGER, b INTEGER, enabled BOOLEAN)")
call ok sql~execute("CREATE TABLE nums (id INTEGER PRIMARY KEY, n INTEGER, grp VARCHAR)")
call ok sql~execute("INSERT INTO pair_src (id,a,b) VALUES (1,10,20),(2,10,30),(3,11,20),(4,99,99)")
call ok sql~execute("INSERT INTO pair_ref (id,a,b,enabled) VALUES (1,10,20,TRUE),(2,11,20,TRUE),(3,99,99,FALSE)")
call ok sql~execute("INSERT INTO nums (id,n,grp) VALUES (1,5,'A'),(2,10,'A'),(3,20,'B'),(4,30,'B')")

rs = sql~execute("SELECT s.id FROM pair_src s WHERE (s.a,s.b) IN (SELECT r.a,r.b FROM pair_ref r WHERE r.enabled=TRUE) ORDER BY s.id")
call assertSuccess rs, "row-value IN"
call assertEq 2, rs~rowCount, "row-value IN count"
call assertEq 1, rs~rows[1]["s.id"], "row-value IN first"
call assertEq 3, rs~rows[2]["s.id"], "row-value IN second"

rs = sql~execute("SELECT x.id FROM nums x WHERE x.n > ALL (SELECT y.n FROM nums y WHERE y.grp='A') ORDER BY x.id")
call assertSuccess rs, "ALL"
call assertEq 2, rs~rowCount, "ALL count"
call assertEq 3, rs~rows[1]["x.id"], "ALL first"
call assertEq 4, rs~rows[2]["x.id"], "ALL second"

rs = sql~execute("SELECT x.id FROM nums x WHERE x.n = ANY (SELECT y.n FROM nums y WHERE y.grp='A') ORDER BY x.id")
call assertSuccess rs, "ANY"
call assertEq 2, rs~rowCount, "ANY count"
call assertEq 1, rs~rows[1]["x.id"], "ANY first"
call assertEq 2, rs~rows[2]["x.id"], "ANY second"

rs = sql~execute("SELECT x.id FROM nums x WHERE x.n = SOME (SELECT y.n FROM nums y WHERE y.grp='A') ORDER BY x.id")
call assertSuccess rs, "SOME alias"
call assertEq 2, rs~rowCount, "SOME count"

rs = sql~execute("SELECT x.id FROM nums x WHERE x.n > ALL (SELECT y.n FROM nums y WHERE y.grp='NOPE') ORDER BY x.id")
call assertSuccess rs, "ALL empty"
call assertEq 4, rs~rowCount, "ALL empty true"

rs = sql~execute("SELECT x.id FROM nums x WHERE x.n = ANY (SELECT y.n FROM nums y WHERE y.grp='NOPE') ORDER BY x.id")
call assertSuccess rs, "ANY empty"
call assertEq 0, rs~rowCount, "ANY empty false"

v = engine~version
call assertEq .NoSQLServerBuild~RELEASE, v~release, "version contract"
call assertTrue v~supports("ROW_VALUE_IN"), "ROW_VALUE_IN capability"
call assertTrue v~supports("QUANTIFIED_COMPARISON"), "QUANTIFIED_COMPARISON capability"

cleanup = .NoSQLServerTestSupport~removeDatabase(root)
say "NOSQLSERVER V0.24 SET/QUANTIFIER SMOKE: OK"
exit 0

ok: procedure
  use arg rs
  if rs~status \= .Error~SUCCESS then do
    say "ASSERT FAILED: SQL operation |" rs~error "|" rs~message
    exit 1
  end
  return

assertSuccess: procedure
  use arg rs, label
  if rs~status \= .Error~SUCCESS then do
    say "ASSERT FAILED:" label "|" rs~error "|" rs~message
    exit 1
  end
  return

assertEq: procedure
  use arg expected, actual, label
  if actual \= expected then do
    say "ASSERT FAILED:" label "expected=" expected "actual=" actual
    exit 1
  end
  return

assertTrue: procedure
  use arg actual, label
  if \actual then do
    say "ASSERT FAILED:" label
    exit 1
  end
  return

::requires "../src/NoSQLServer.cls"
::requires "TestSupport.cls"
