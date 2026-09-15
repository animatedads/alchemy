schema = .DatabaseResultSchema~new
schema~add("value", .DatabaseType~INTEGER)
conn = .DatabaseConnection~new("localhost", 5432, "test", "tester", .nil, "postgresql")
executor = .RetryQueryExecutor~new
db = .Database~new(conn, .nil, executor)
tx = db~transaction
call assert (tx~setRetryAttempts(2) = .Error~SUCCESS), "set retry"
ref = tx~queryWithSchema("SELECT 42 AS value", schema)
rs = tx~commit
call assert (rs~status = .Error~SUCCESS), "commit"
call assert (rs~attemptCount = 2), "two attempts"
call assert ref~resolved, "query resolved"
call assert (ref~result~rowCount = 1), "one row"
call assert (ref~result~rows[1]~valueAt("value") = "42"), "final result"
say "DATABASE TRANSACTION RETRY QUERY SMOKE: OK"
exit 0
assert: procedure
  use arg condition, label
  if \condition then do
    say "ASSERTION FAILED:" label
    exit 9
  end
  return
::class RetryQueryExecutor public subclass DatabaseCommandExecutor
::method init
  expose callCount
  callCount = 0
::method execute
  expose callCount
  use arg command
  callCount += 1
  if callCount = 1 then return .DatabaseCommandResult~new(3, "", "ERROR: could not serialize access due to concurrent update", command, "PROCESS")
  out = "__oorexx_frame" || .endOfLine || -
        "__OOREXX_RESULT_BEGIN_1__" || .endOfLine || -
        "value" || .endOfLine || -
        "42" || .endOfLine || -
        "__oorexx_frame" || .endOfLine || -
        "__OOREXX_RESULT_END_1__" || .endOfLine
  return .DatabaseCommandResult~new(0, out, "", command, "PROCESS")
::requires "database_core.cls"
