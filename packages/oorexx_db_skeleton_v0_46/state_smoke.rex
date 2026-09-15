conn = .DatabaseConnection~new("localhost", 5432, "test", "tester", .nil, "postgresql")
db = .Database~new(conn)

tx = db~transaction
tx~execute("DELETE FROM t WHERE id = 1")
rollbackResult = tx~rollback
call assert rollbackResult~outcome = .Error~NOTEXECUTED, "build-time rollback is not executed"
call assert rollbackResult~status = .Error~NOTEXECUTED, "rollback status constant"
call assert rollbackResult~error = .Error~SUCCESS, "discard is not an execution error"
call assert tx~state = "rolled-back", "rollback state"
secondCommit = tx~commit
call assert secondCommit~outcome = .Error~NOTEXECUTED, "cannot commit discarded transaction"
call assert secondCommit~error = .Error~INVALIDSTATE, "invalid-state error constant"

params = .DatabaseParameterSet~new
p1 = params~add("alpha")
p2 = params~add(.DatabaseParameter~new(.nil, "varchar"))
call assert params~count = 2, "parameter count"
call assert params~at(1)~value = "alpha", "parameter normalization"
call assert params~at(2)~isNull, "null parameter"

stmt = .DatabasePreparedStatement~new("x", "INSERT INTO x(v) VALUES (?)")
batch = .DatabasePreparedBatch~new(stmt)
batch~add(.DatabasePreparedExecution~new(stmt, params))
call assert batch~count = 1, "prepared batch count"

say "DATABASE STATE SMOKE: OK"
exit 0

assert: procedure
  use arg condition, label
  if \condition then do
    say "ASSERTION FAILED:" label
    exit 9
  end
  return

::requires "database_core.cls"
