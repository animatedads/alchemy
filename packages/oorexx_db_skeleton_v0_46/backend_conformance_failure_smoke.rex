provider = .BrokenProvider~new
suiteResult = .DatabaseBackendConformanceSuite~new~run(provider)

call assert (\suiteResult~success), "broken backend must fail"
call assert (suiteResult~failed > 0), "failure recorded"

found = .false
do line over suiteResult~details
  if line~pos("FAIL transaction_commit") = 1 then found = .true
end
call assert found, "transaction failure surfaced"

say "DATABASE BACKEND CONFORMANCE FAILURE SMOKE: OK"
exit 0

assert: procedure
  use arg condition, label
  if \condition then do
    say "ASSERTION FAILED:" label
    exit 9
  end
  return

::class BrokenProvider public subclass DatabaseConformanceProvider
::method init
  expose db
  conn = .DatabaseConnection~new("localhost", 5432, "test", "tester", .nil, "postgresql")
  db = .Database~new(conn, .nil, .BrokenExecutor~new)
::method name
  return "broken"
::method supports
  use arg capability
  if capability = .DatabaseCapability~TRANSACTIONS then return .true
  return .false
::method reset
  use arg scenario
  return .Error~SUCCESS
::method database
  expose db
  return db
::method readFixtureValue
  return "1"

::class BrokenExecutor public subclass DatabaseCommandExecutor
::method execute
  use arg command
  /* Claims success but never changes observable state. */
  return .DatabaseCommandResult~new(0, "UPDATE 1" || .endOfLine, "", command, "PROCESS")

::requires "database_core.cls"
