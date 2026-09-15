identity = .DatabaseTransactionIdentity~new("legacy-append")
db = .DirectAppendDatabase~new
tx = db~transaction(.nil, identity)

ps = tx~prepareStatement("p", "UPDATE t SET x = ?")
batch = .DatabasePreparedBatch~new(ps)
params = .DatabaseParameterSet~new
params~add(.DatabaseParameter~new(1))
batch~add(.DatabasePreparedExecution~new(ps, params))

/* Historical public operations collection seam. */
tx~operations~append(batch)
call assert batch~operationId = "", "direct append initially unbound"

rs = tx~commit
call assert rs~status = .Error~SUCCESS, "legacy direct append commits"
call assert batch~transactionId = "legacy-append", "commit binds transaction"
call assert batch~operationSequence = 2, "commit binds transaction order"
call assert batch~operationId = "legacy-append:op:2", "commit binds stable id"
call assert rs~mutationResults[1]~operationId = batch~operationId, "result maps bound batch"

say "DATABASE DIRECT APPEND OPERATION IDENTITY SMOKE: OK"
exit 0

assert: procedure
  use arg condition, label
  if \condition then do
    say "ASSERTION FAILED:" label
    exit 9
  end
  return

::class DirectAppendDatabase public subclass Database
::method init
  conn = .DatabaseConnection~new("fake", 5432, "fakedb", "", .nil, "postgresql")
  self~init:super(conn, .DirectAppendEngine~new, .DirectAppendExecutor~new)

::class DirectAppendEngine public subclass PostgreSQLEngine
::method parser
  return .DirectAppendParser~new

::class DirectAppendExecutor public subclass DatabaseCommandExecutor
::method execute
  use arg command
  return .DatabaseCommandResult~new(0, "OK", "", command, "PROCESS")

::class DirectAppendParser public subclass PostgreSQLResultParser
::method parseMutationResults
  use arg commandResult
  a = .array~new
  a~append(.DatabaseMutationResult~new(.Error~SUCCESS, .Error~SUCCESS, 1))
  return a

::requires "database_core.cls"
