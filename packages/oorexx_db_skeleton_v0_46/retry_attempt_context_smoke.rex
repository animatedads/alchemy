context = .DatabaseExecutionContext~new(.EvidenceStub~new("GEN-A"), "retry:test")
db = .RetryDatabase~new

tx = db~transaction(context)
status = tx~setRetryAttempts(2)
call assert status = .Error~SUCCESS, "retry attempts accepted"
tx~execute("UPDATE account SET balance = balance + 1 WHERE id = 1")

rs = tx~commit

call assert rs~status = .Error~SUCCESS, "retry transaction succeeds"
call assert rs~attemptCount = 2, "two attempts"
call assert rs~attempts~items = 2, "attempt trail count"
call assert rs~lastAttempt == rs~attempts[2], "last attempt helper"

a1 = rs~attempts[1]
a2 = rs~attempts[2]

call assert a1~attemptNumber = 1, "first attempt number"
call assert a1~error = .Error~DEADLOCK, "first attempt classified deadlock"
call assert a1~retryable, "first attempt retryable"
call assert a1~executionContext == context, "first attempt context"
call assert a1~evidence == context~evidence, "first attempt evidence"
call assert a1~commandResult~executionContext == context, "first command context"

call assert a2~attemptNumber = 2, "second attempt number"
call assert a2~status = .Error~SUCCESS, "second attempt success"
call assert a2~error = .Error~SUCCESS, "second attempt error success"
call assert \a2~retryable, "successful attempt not retryable"
call assert a2~executionContext == context, "second attempt context"
call assert a2~commandResult~executionContext == context, "second command context"

call assert a1~commandResult \== a2~commandResult, "attempt command results retained independently"

say "DATABASE RETRY ATTEMPT CONTEXT SMOKE: OK"
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

::class RetryDatabase public subclass Database
::method init
  conn = .DatabaseConnection~new("fake", 5432, "fakedb", "", .nil, "postgresql")
  self~init:super(conn, .RetryEngine~new, .RetryExecutor~new)

::class RetryEngine public subclass PostgreSQLEngine
::method parser
  return .RetryParser~new

::class RetryExecutor public subclass DatabaseCommandExecutor
::method init
  expose count
  count = 0
::method execute
  expose count
  use arg command
  count += 1
  if count = 1 then return .DatabaseCommandResult~new(1, "", "deadlock detected", command, "PROCESS")
  return .DatabaseCommandResult~new(0, "UPDATE 1" || .endOfLine, "", command, "PROCESS")

::class RetryParser public subclass PostgreSQLResultParser
::method parse
  use arg commandResult
  if commandResult~rc = 1 then return .DatabaseResult~new(.Error~FAILED, .Error~DEADLOCK)
  return .DatabaseResult~new(.Error~SUCCESS, .Error~SUCCESS)

::requires "database_core.cls"
