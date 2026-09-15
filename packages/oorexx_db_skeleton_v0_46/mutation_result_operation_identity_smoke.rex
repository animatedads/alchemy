identity = .DatabaseTransactionIdentity~new("mutation-op")
db = .MutationIdentityDatabase~new
tx = db~transaction(.nil, identity)

op1 = tx~execute("UPDATE t SET x = 1")
ps = tx~prepareStatement("p", "UPDATE t SET x = ?")
op3 = tx~executePrepared(ps, .array~of(2))
batch = .DatabasePreparedBatch~new(ps)
p1 = .DatabaseParameterSet~new
p1~add(.DatabaseParameter~new(3))
batch~add(.DatabasePreparedExecution~new(ps, p1))
p2 = .DatabaseParameterSet~new
p2~add(.DatabaseParameter~new(4))
batch~add(.DatabasePreparedExecution~new(ps, p2))
tx~operations~append(batch)

rs = tx~commit
m = rs~mutationResults

call assert rs~status = .Error~SUCCESS, "transaction committed"
call assert m~items = 4, "four mutation results"
call assert m[1]~operationId = op1~operationId, "ordinary execute mapping"
call assert m[2]~operationId = op3~operationId, "prepared execute mapping"
call assert m[3]~operationId = batch~operationId, "batch result one mapping"
call assert m[4]~operationId = batch~operationId, "batch result two mapping"
call assert m[1]~transactionId = "mutation-op", "mutation transaction id"
call assert m[4]~operationSequence = batch~operationSequence, "batch sequence retained"

say "DATABASE MUTATION RESULT OPERATION IDENTITY SMOKE: OK"
exit 0

assert: procedure
  use arg condition, label
  if \condition then do
    say "ASSERTION FAILED:" label
    exit 9
  end
  return

::class MutationIdentityDatabase public subclass Database
::method init
  conn = .DatabaseConnection~new("fake", 5432, "fakedb", "", .nil, "postgresql")
  self~init:super(conn, .MutationIdentityEngine~new, .MutationIdentityExecutor~new)

::class MutationIdentityEngine public subclass PostgreSQLEngine
::method parser
  return .MutationIdentityParser~new

::class MutationIdentityExecutor public subclass DatabaseCommandExecutor
::method execute
  use arg command
  return .DatabaseCommandResult~new(0, "OK", "", command, "PROCESS")

::class MutationIdentityParser public subclass PostgreSQLResultParser
::method parseMutationResults
  use arg commandResult
  results = .array~new
  do i = 1 to 4
    results~append(.DatabaseMutationResult~new(.Error~SUCCESS, .Error~SUCCESS, i))
  end
  return results

::requires "database_core.cls"
