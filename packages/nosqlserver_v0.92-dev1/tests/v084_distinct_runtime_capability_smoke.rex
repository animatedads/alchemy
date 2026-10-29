root = .NoSQLServerTestSupport~createBlankDatabase("v084-distinct-capability")
engine = .FileDatabaseEngine~new(root)
sql = .NoSQLServerSQL~new(engine)

call assertSuccess sql~execute("CREATE TABLE sample (id INTEGER PRIMARY KEY, label VARCHAR(32) NOT NULL)")
call assertSuccess sql~execute("INSERT INTO sample (id, label) VALUES (1,'alpha'),(2,'alpha'),(3,'beta'),(4,'beta'),(5,'gamma')")

rs = sql~execute("SELECT DISTINCT label FROM sample ORDER BY label")
call assertSuccess rs
call assertEqual 3, rs~rows~items, "DISTINCT collapses duplicates"
call assertEqual "alpha", rs~rows[1]["label"], "DISTINCT alpha"
call assertEqual "beta", rs~rows[2]["label"], "DISTINCT beta"
call assertEqual "gamma", rs~rows[3]["label"], "DISTINCT gamma"

call assertTrue engine~version~supports("DISTINCT"), "version advertises DISTINCT"
adapter = .NoSQLDatabaseCoreAdapter~new(engine)
call assertTrue adapter~supports(.NoSQLDatabaseCoreCapability~DISTINCT), "Database Core advertises DISTINCT"

projection = .NoSQLDatabaseRuntimeEvidenceProjection~new(adapter)
found = .false
do line over projection~lines
  if line = "DATABASE CAPABILITY_DISTINCT TRUE" then found = .true
end
call assertTrue found, "runtime evidence publishes DATABASE CAPABILITY_DISTINCT TRUE"

cleanupResult = .NoSQLServerTestSupport~removeDatabase(root)
say "NOSQLSERVER V0.84 DISTINCT RUNTIME CAPABILITY SMOKE: OK"
exit 0

assertSuccess: procedure
  use arg rs
  if rs~status \= .Error~SUCCESS then do
    say "ASSERT FAILED: expected SUCCESS got" rs~status rs~error rs~message
    exit 1
  end
  return

assertEqual: procedure
  use arg expected, actual, label
  if expected \== actual then do
    say "ASSERT FAILED:" label "expected=" expected "actual=" actual
    exit 1
  end
  return

assertTrue: procedure
  use arg value, label
  if \value then do
    say "ASSERT FAILED:" label
    exit 1
  end
  return

::requires "../src/NoSQLServer.cls"
::requires "TestSupport.cls"
