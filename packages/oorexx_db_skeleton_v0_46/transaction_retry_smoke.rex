conn = .DatabaseConnection~new("localhost", 5432, "test", "tester", .nil, "postgresql")
executor = .RetryExecutor~new
db = .Database~new(conn, .nil, executor)
tx = db~transaction
call assert (tx~setRetryAttempts(3) = .Error~SUCCESS), "set retries"
tx~execute("UPDATE account SET balance = balance + 1 WHERE id = 1")
rs = tx~commit
call assert (rs~status = .Error~SUCCESS), "eventual success"
call assert (rs~outcome = .Error~COMMITTED), "committed"
call assert (rs~attemptCount = 2), "two attempts"
call assert rs~retried, "retried"
call assert (executor~callCount = 2), "whole transaction executed twice"
say "DATABASE TRANSACTION RETRY SMOKE: OK"
exit 0
assert: procedure
  use arg condition, label
  if \condition then do
    say "ASSERTION FAILED:" label
    exit 9
  end
  return
::class RetryExecutor public subclass DatabaseCommandExecutor
::method init
  expose callCount
  callCount = 0
::attribute callCount get
::method execute
  expose callCount
  use arg command
  callCount += 1
  if callCount = 1 then return .DatabaseCommandResult~new(3, "", "ERROR: deadlock detected", command, "PROCESS")
  return .DatabaseCommandResult~new(0, "", "", command, "PROCESS")
::requires "database_core.cls"
