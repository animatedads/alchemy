identity = .DatabaseTransactionIdentity~new("logical-retry-op")
db = .RetryOperationDatabase~new
tx = db~transaction(.nil, identity)
status = tx~setRetryAttempts(2)
call assert status = .Error~SUCCESS, "retry configured"

op1 = tx~execute("UPDATE t SET x = x + 1")
op2 = tx~execute("UPDATE t SET y = y + 1")

rs = tx~commit

call assert rs~status = .Error~SUCCESS, "retry committed"
call assert rs~attemptCount = 2, "two physical attempts"
call assert op1~operationId = "logical-retry-op:op:1", "op1 stable id"
call assert op2~operationId = "logical-retry-op:op:2", "op2 stable id"
call assert rs~operationIds~items = 2, "result operation ids"
call assert rs~operationIds[1] = op1~operationId, "result op1 identity"
call assert rs~operationIds[2] = op2~operationId, "result op2 identity"
call assert rs~attempts[1]~transactionId = "logical-retry-op", "attempt1 same logical tx"
call assert rs~attempts[2]~transactionId = "logical-retry-op", "attempt2 same logical tx"

say "DATABASE OPERATION IDENTITY RETRY SMOKE: OK"
exit 0

assert: procedure
  use arg condition, label
  if \condition then do
    say "ASSERTION FAILED:" label
    exit 9
  end
  return

::class RetryOperationDatabase public subclass Database
::method init
  conn = .DatabaseConnection~new("fake", 5432, "fakedb", "", .nil, "postgresql")
  self~init:super(conn, .RetryOperationEngine~new, .RetryOperationExecutor~new)

::class RetryOperationEngine public subclass PostgreSQLEngine
::method parser
  return .RetryOperationParser~new

::class RetryOperationExecutor public subclass DatabaseCommandExecutor
::method init
  expose count
  count = 0
::method execute
  expose count
  use arg command
  count += 1
  if count = 1 then return .DatabaseCommandResult~new(1, "", "deadlock detected", command, "PROCESS")
  return .DatabaseCommandResult~new(0, "UPDATE 1" || .endOfLine || "UPDATE 1" || .endOfLine, "", command, "PROCESS")

::class RetryOperationParser public subclass PostgreSQLResultParser
::method parse
  use arg commandResult
  if commandResult~rc = 1 then return .DatabaseResult~new(.Error~FAILED, .Error~DEADLOCK)
  return .DatabaseResult~new(.Error~SUCCESS, .Error~SUCCESS)

::requires "database_core.cls"
