conn = .DatabaseConnection~new("localhost", 5432, "test", "tester", .nil, "postgresql")
executor1 = .DeadlockExecutor~new
db1 = .Database~new(conn, .nil, executor1)
tx1 = db1~transaction
tx1~execute("UPDATE t SET v = 1")
r1 = tx1~commit
call assert (r1~error = .Error~DEADLOCK), "default deadlock"
call assert (r1~attemptCount = 1), "default one attempt"
call assert (\r1~retried), "default no retry"

executor2 = .DeadlockExecutor~new
db2 = .Database~new(conn, .nil, executor2)
tx2 = db2~transaction
call assert (tx2~setRetryAttempts(3) = .Error~SUCCESS), "set retry"
tx2~execute("UPDATE t SET v = 1")
r2 = tx2~commit
call assert (r2~status = .Error~ROLLEDBACK), "rollback after exhaustion"
call assert (r2~error = .Error~DEADLOCK), "real final error retained"
call assert (r2~attemptCount = 3), "three attempts"
call assert r2~retried, "retried flag"

executor3 = .SyntaxExecutor~new
db3 = .Database~new(conn, .nil, executor3)
tx3 = db3~transaction
call assert (tx3~setRetryAttempts(5) = .Error~SUCCESS), "set retry 5"
tx3~execute("SELEC 1")
r3 = tx3~commit
call assert (r3~error = .Error~SYNTAXERROR), "syntax retained"
call assert (r3~attemptCount = 1), "syntax one attempt"
call assert (executor3~callCount = 1), "syntax not replayed"
call assert (tx3~setRetryAttempts(2) = .Error~INVALIDSTATE), "state guard"

say "DATABASE TRANSACTION RETRY GUARD SMOKE: OK"
exit 0
assert: procedure
  use arg condition, label
  if \condition then do
    say "ASSERTION FAILED:" label
    exit 9
  end
  return
::class DeadlockExecutor public subclass DatabaseCommandExecutor
::method init
  expose callCount
  callCount = 0
::attribute callCount get
::method execute
  expose callCount
  use arg command
  callCount += 1
  return .DatabaseCommandResult~new(3, "", "ERROR: deadlock detected", command, "PROCESS")
::class SyntaxExecutor public subclass DatabaseCommandExecutor
::method init
  expose callCount
  callCount = 0
::attribute callCount get
::method execute
  expose callCount
  use arg command
  callCount += 1
  return .DatabaseCommandResult~new(3, "", "ERROR: syntax error at or near ""SELEC""", command, "PROCESS")
::requires "database_core.cls"
