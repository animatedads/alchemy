identity = .DatabaseTransactionIdentity~new("query-op")
db = .QueryIdentityDatabase~new
tx = db~transaction(.nil, identity)
ref = tx~query("SELECT 42 AS answer")
rs = tx~commit

call assert rs~status = .Error~SUCCESS, "transaction committed"
call assert ref~resolved, "query resolved"
qr = ref~result
call assert qr~transactionId = "query-op", "query result transaction id"
call assert qr~operationId = "query-op:op:1", "query result operation id"
call assert qr~operationSequence = 1, "query result operation sequence"
call assert ref~operationId = qr~operationId, "deferred/result identity agrees"

say "DATABASE QUERY RESULT OPERATION IDENTITY SMOKE: OK"
exit 0

assert: procedure
  use arg condition, label
  if \condition then do
    say "ASSERTION FAILED:" label
    exit 9
  end
  return

::class QueryIdentityDatabase public subclass Database
::method init
  conn = .DatabaseConnection~new("fake", 5432, "fakedb", "", .nil, "postgresql")
  self~init:super(conn, .PostgreSQLEngine~new, .QueryIdentityExecutor~new)

::class QueryIdentityExecutor public subclass DatabaseCommandExecutor
::method execute
  use arg command
  stdout = "__OOREXX_RESULT_BEGIN_1__" || .endOfLine || -
           "answer" || .endOfLine || -
           "42" || .endOfLine || -
           "__OOREXX_RESULT_END_1__" || .endOfLine
  return .DatabaseCommandResult~new(0, stdout, "", command, "PROCESS")

::requires "database_core.cls"
