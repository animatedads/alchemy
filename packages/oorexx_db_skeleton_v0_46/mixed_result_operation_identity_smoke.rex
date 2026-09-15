identity = .DatabaseTransactionIdentity~new("mixed-op")
db = .MixedIdentityDatabase~new
tx = db~transaction(.nil, identity)

updateOp = tx~execute("UPDATE t SET x = 1")
queryRef = tx~query("SELECT x FROM t")
deleteOp = tx~execute("DELETE FROM t WHERE x = 1")

rs = tx~commit
m = rs~mutationResults

call assert m~items = 2, "two mutation results"
call assert m[1]~operationId = updateOp~operationId, "update maps correctly"
call assert m[2]~operationId = deleteOp~operationId, "delete skips query operation"
call assert queryRef~result~operationId = queryRef~operationId, "query maps independently"

say "DATABASE MIXED RESULT OPERATION IDENTITY SMOKE: OK"
exit 0

assert: procedure
  use arg condition, label
  if \condition then do
    say "ASSERTION FAILED:" label
    exit 9
  end
  return

::class MixedIdentityDatabase public subclass Database
::method init
  conn = .DatabaseConnection~new("fake", 5432, "fakedb", "", .nil, "postgresql")
  self~init:super(conn, .MixedIdentityEngine~new, .MixedIdentityExecutor~new)

::class MixedIdentityEngine public subclass PostgreSQLEngine
::method parser
  return .MixedIdentityParser~new

::class MixedIdentityExecutor public subclass DatabaseCommandExecutor
::method execute
  use arg command
  stdout = "__OOREXX_RESULT_BEGIN_1__" || .endOfLine || -
           "x" || .endOfLine || -
           "1" || .endOfLine || -
           "__OOREXX_RESULT_END_1__" || .endOfLine
  return .DatabaseCommandResult~new(0, stdout, "", command, "PROCESS")

::class MixedIdentityParser public subclass PostgreSQLResultParser
::method parseMutationResults
  use arg commandResult
  results = .array~new
  results~append(.DatabaseMutationResult~new(.Error~SUCCESS, .Error~SUCCESS, 1))
  results~append(.DatabaseMutationResult~new(.Error~SUCCESS, .Error~SUCCESS, 1))
  return results

::requires "database_core.cls"
