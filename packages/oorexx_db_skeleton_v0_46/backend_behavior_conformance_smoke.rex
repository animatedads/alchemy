provider = .StatefulPostgreSQLProvider~new
suite = .DatabaseBackendConformanceSuite~new
suiteResult = suite~run(provider)

do line over suiteResult~details
  say line
end

call assert suiteResult~success, "suite success"
call assert (suiteResult~failed = 0), "no failures"
call assert (suiteResult~passed = 8), "eight scenarios"

say "DATABASE BACKEND STATEFUL CONFORMANCE SMOKE: OK"
exit 0

assert: procedure
  use arg condition, label
  if \condition then do
    say "ASSERTION FAILED:" label
    exit 9
  end
  return

::class StatefulPostgreSQLProvider public subclass DatabaseConformanceProvider
::method init
  expose db executor
  executor = .StatefulConformanceExecutor~new
  conn = .DatabaseConnection~new("localhost", 5432, "test", "tester", .nil, "postgresql")
  db = .Database~new(conn, .nil, executor)
::method name
  return "postgresql-stateful-simulated"
::method supports
  expose db
  use arg capability
  return db~supports(capability)
::method reset
  expose executor
  use arg scenario
  executor~reset(scenario)
  return .Error~SUCCESS
::method database
  expose db
  return db
::method readFixtureValue
  expose executor
  return executor~value
::method fixtureRowCount
  expose executor
  return executor~rowCount

::class StatefulConformanceExecutor public subclass DatabaseCommandExecutor
::method init
  expose scenario callCount value rowCount
  scenario = ""
  callCount = 0
  value = "1"
  rowCount = 1
::attribute scenario
::attribute callCount
::attribute value get
::attribute rowCount get
::method reset
  expose scenario callCount value rowCount
  use arg newScenario
  scenario = newScenario
  callCount = 0
  value = "1"
  rowCount = 1
  return self
::method execute
  expose scenario callCount value rowCount
  use arg command
  callCount += 1
  sql = command~stdinText

  if scenario = "deferred_query" then do
    out = "__oorexx_frame" || .endOfLine || -
          "__OOREXX_RESULT_BEGIN_1__" || .endOfLine || -
          "id" || "09"x || "value" || .endOfLine || -
          "1" || "09"x || value || .endOfLine || -
          "__oorexx_frame" || .endOfLine || -
          "__OOREXX_RESULT_END_1__" || .endOfLine
    return .DatabaseCommandResult~new(0, out, "", command, "PROCESS")
  end

  if scenario = "transaction_retry" then do
    if callCount = 1 then -
      return .DatabaseCommandResult~new(3, "", "ERROR: deadlock detected", command, "PROCESS")
    value = "10"
    return .DatabaseCommandResult~new(0, "UPDATE 1" || .endOfLine, "", command, "PROCESS")
  end

  if scenario = "generated_keys" then do
    rowCount += 1
    out = "__oorexx_generated_key" || .endOfLine || -
          "101" || .endOfLine || -
          "INSERT 0 1" || .endOfLine
    return .DatabaseCommandResult~new(0, out, "", command, "PROCESS")
  end

  if scenario = "transaction_commit" then do
    value = "2"
    return .DatabaseCommandResult~new(0, "UPDATE 1" || .endOfLine, "", command, "PROCESS")
  end

  if scenario = "rollback_before_commit" then do
    /* rollback before commit never calls the executor */
    return .DatabaseCommandResult~new(0, "", "", command, "PROCESS")
  end

  if scenario = "prepared_statement" then do
    value = "5"
    return .DatabaseCommandResult~new(0, "UPDATE 1" || .endOfLine, "", command, "PROCESS")
  end

  if scenario = "prepared_batch" then do
    value = "7"
    return .DatabaseCommandResult~new(0, "UPDATE 1" || .endOfLine || "UPDATE 1" || .endOfLine, "", command, "PROCESS")
  end

  if scenario = "mutation_results" then do
    value = "8"
    return .DatabaseCommandResult~new(0, "UPDATE 1" || .endOfLine, "", command, "PROCESS")
  end

  return .DatabaseCommandResult~new(0, "", "", command, "PROCESS")

::requires "database_core.cls"
