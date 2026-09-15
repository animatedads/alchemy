context1 = .DatabaseExecutionContext~new(.EvidenceStub~new("A"), "test:A")
context2 = .DatabaseExecutionContext~new(.EvidenceStub~new("B"), "test:B")

db = .MutationContextDatabase~new
tx = db~transaction(context1)
ref = tx~query("SELECT 1 AS value")

call assert ref~executionContext == context1, "initial ref context"
status = tx~setExecutionContext(context2)
call assert status = .Error~SUCCESS, "replace context while building"
call assert ref~executionContext == context2, "existing ref follows replacement"

tx~execute("UPDATE t SET v = 1")
rs = tx~commit

call assert rs~executionContext == context2, "transaction result replacement context"
call assert rs~commandResult~executionContext == context2, "command result replacement context"
call assert rs~mutationResults~items = 1, "one mutation result"
call assert rs~mutationResults[1]~executionContext == context2, "mutation result context"
call assert rs~mutationResults[1]~evidence == context2~evidence, "mutation result evidence"

status = tx~setExecutionContext(context1)
call assert status = .Error~INVALIDSTATE, "context immutable after execution"

say "DATABASE MUTATION EXECUTION CONTEXT SMOKE: OK"
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

::class MutationContextDatabase public subclass Database
::method init
  conn = .DatabaseConnection~new("fake", 5432, "fakedb", "", .nil, "postgresql")
  self~init:super(conn, .MutationContextEngine~new, .MutationContextExecutor~new)

::class MutationContextEngine public subclass PostgreSQLEngine
::method parser
  return .MutationContextParser~new

::class MutationContextExecutor public subclass DatabaseCommandExecutor
::method execute
  use arg command
  stdout = "__OOREXX_RESULT_BEGIN_1__" || .endOfLine || -
           "value" || .endOfLine || -
           "1" || .endOfLine || -
           "__OOREXX_RESULT_END_1__" || .endOfLine || -
           "UPDATE 1" || .endOfLine
  return .DatabaseCommandResult~new(0, stdout, "", command, "PROCESS")

::class MutationContextParser public subclass PostgreSQLResultParser
::method parseMutationResults
  use arg commandResult
  a = .array~new
  a~append(.DatabaseMutationResult~new(.Error~SUCCESS, .Error~SUCCESS, 1))
  return a

::requires "database_core.cls"
