context = .DatabaseExecutionContext~new(.EvidenceStub~new("GEN-X"), "invalid-plan")
conn = .DatabaseConnection~new("fake", 5432, "fakedb", "", .nil, "postgresql")
db = .Database~new(conn)

tx = db~transaction(context)
ps = tx~prepareStatement("p", "INSERT INTO t(a,b) VALUES (?, ?)")
tx~executePrepared(ps, .array~of(1))
rs = tx~commit

call assert rs~status = .Error~NOTEXECUTED, "invalid plan not executed"
call assert rs~error = .Error~PARAMETERCOUNT, "invalid plan error"
call assert rs~attempts~items = 1, "notexecuted attempt retained"
attempt = rs~attempts[1]
call assert attempt~status = .Error~NOTEXECUTED, "attempt notexecuted"
call assert attempt~error = .Error~PARAMETERCOUNT, "attempt plan error"
call assert \attempt~retryable, "notexecuted not retryable"
call assert attempt~executionContext == context, "attempt context"
call assert attempt~commandResult~executionContext == context, "notexecuted command context"

say "DATABASE NOTEXECUTED ATTEMPT CONTEXT SMOKE: OK"
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

::requires "database_core.cls"
