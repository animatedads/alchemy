evidence = .FakeEvidence~new("generation-42")
context = .DatabaseExecutionContext~new(evidence, "db://accounts/tx-1")
conn = .DatabaseConnection~new("fake", 5432, "accounts", "app", .nil, "postgresql")
db = .Database~new(conn)
tx = db~transaction(context)
tx~execute("UPDATE account SET balance = balance + 1 WHERE id = 1")
rs = tx~commit

call assert rs~status = .Error~SUCCESS, "transaction success"
call assert rs~executionContext == context, "context retained by identity"
call assert rs~evidence == evidence, "evidence retained by identity"
call assert rs~executionContext~locator = "db://accounts/tx-1", "locator retained"
p = rs~executionContext~provenance
call assert p["kind"] = "DATABASE_EXECUTION_CONTEXT", "context provenance kind"
call assert p["evidence"]["generation_id"] = "generation-42", "nested evidence provenance"

late = .DatabaseExecutionContext~new(.FakeEvidence~new("late"), "late")
call assert tx~setExecutionContext(late) = .Error~INVALIDSTATE, "committed transaction context immutable"

say "DATABASE EXECUTION CONTEXT SMOKE: OK"
exit 0

assert: procedure
  use arg condition, label
  if \condition then do
    say "ASSERTION FAILED:" label
    exit 9
  end
  return

::class FakeEvidence public
::method init
  expose generationId
  use arg generationId
::method provenance
  expose generationId
  p = .directory~new
  p["generation_id"] = generationId
  return p

::requires "database_core.cls"
