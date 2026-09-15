identity = .DatabaseTransactionIdentity~new("logical-retry-42")
context = .DatabaseExecutionContext~new(.EvidenceStub~new("GEN-A"), "retry:identity")
db = .RetryIdentityDatabase~new

tx = db~transaction(context, identity)
status = tx~setRetryAttempts(3)
call assert status = .Error~SUCCESS, "retry configured"
tx~execute("UPDATE account SET balance = balance + 1 WHERE id = 1")

rs = tx~commit

call assert rs~status = .Error~SUCCESS, "transaction succeeds"
call assert rs~transactionIdentity == identity, "result logical identity"
call assert rs~transactionId = "logical-retry-42", "result transaction id"
call assert rs~attempts~items = 3, "three physical attempts"

do i = 1 to rs~attempts~items
  attempt = rs~attempts[i]
  call assert attempt~transactionId = rs~transactionId, "attempt belongs to logical transaction"
  expectedAttemptId = "logical-retry-42:attempt:" || i
  call assert attempt~attemptId = expectedAttemptId, "attempt id deterministic"
  call assert attempt~attemptNumber = i, "attempt number"
end

call assert rs~attempts[1]~retryable, "first retryable"
call assert rs~attempts[2]~retryable, "second retryable"
call assert \rs~attempts[3]~retryable, "success not retryable"

say "DATABASE RETRY ATTEMPT IDENTITY SMOKE: OK"
exit 0

assert: procedure
  use arg condition, label
  if \condition then do
    say "ASSERTION FAILED:" label
    exit 9
  end
  return

::class EvidenceStub public
::method init
  expose label
  use arg label
::attribute label get

::class RetryIdentityDatabase public subclass Database
::method init
  conn = .DatabaseConnection~new("fake", 5432, "fakedb", "", .nil, "postgresql")
  self~init:super(conn, .RetryIdentityEngine~new, .RetryIdentityExecutor~new)

::class RetryIdentityEngine public subclass PostgreSQLEngine
::method parser
  return .RetryIdentityParser~new

::class RetryIdentityExecutor public subclass DatabaseCommandExecutor
::method init
  expose count
  count = 0
::method execute
  expose count
  use arg command
  count += 1
  if count < 3 then return .DatabaseCommandResult~new(1, "", "deadlock detected", command, "PROCESS")
  return .DatabaseCommandResult~new(0, "UPDATE 1" || .endOfLine, "", command, "PROCESS")

::class RetryIdentityParser public subclass PostgreSQLResultParser
::method parse
  use arg commandResult
  if commandResult~rc = 1 then return .DatabaseResult~new(.Error~FAILED, .Error~DEADLOCK)
  return .DatabaseResult~new(.Error~SUCCESS, .Error~SUCCESS)

::requires "database_core.cls"
