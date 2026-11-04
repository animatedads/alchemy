parse arg root
if root = "" then root = .NoSQLServerTestSupport~createBlankDatabase("runtime-evidence")
created = .false
if arg() = 0 | arg(1) = "" then created = .true

engine = .FileDatabaseEngine~new(root)
adapter = .NoSQLDatabaseCoreAdapter~new(engine)
projection = .NoSQLDatabaseRuntimeEvidenceProjection~new(adapter)
do line over projection~lines
  say line
end
if created then cleanupResult = .NoSQLServerTestSupport~removeDatabase(root)
exit 0

::requires "../src/NoSQLServer.cls"
::requires "../tests/TestSupport.cls"
