evidence = .EvidenceStub~new("generation-A")
context = .DatabaseExecutionContext~new(evidence, "test:query")

db = .ContextDatabase~new
tx = db~transaction(context)
ref = tx~query("SELECT 42 AS value")

call assert ref~executionContext == context, "deferred reference context"
call assert ref~evidence == evidence, "deferred reference evidence"

rs = tx~commit
call assert rs~executionContext == context, "transaction result context"
call assert rs~evidence == evidence, "transaction result evidence"
call assert rs~commandResult~executionContext == context, "command result context"
call assert ref~resolved, "query ref resolved"
call assert ref~result~executionContext == context, "query result context"
call assert ref~result~evidence == evidence, "query result evidence"
call assert ref~result~rows[1]~valueAt("value") = 42, "query result value"

say "DATABASE RESULT EXECUTION CONTEXT SMOKE: OK"
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
::method provenance
  expose label
  p = .directory~new
  p["label"] = label
  return p

::class ContextDatabase public subclass Database
::method init
  conn = .DatabaseConnection~new("fake", 5432, "fakedb", "", .nil, "postgresql")
  self~init:super(conn, .ContextEngine~new, .ContextExecutor~new)

::class ContextEngine public subclass PostgreSQLEngine
::method parser
  return .ContextParser~new

::class ContextExecutor public subclass DatabaseCommandExecutor
::method execute
  use arg command
  stdout = "__OOREXX_RESULT_BEGIN_1__" || .endOfLine || -
           "value" || .endOfLine || -
           "42" || .endOfLine || -
           "__OOREXX_RESULT_END_1__" || .endOfLine
  return .DatabaseCommandResult~new(0, stdout, "", command, "PROCESS")

::class ContextParser public subclass PostgreSQLResultParser

::requires "database_core.cls"
