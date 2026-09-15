identity = .DatabaseTransactionIdentity~new("manifest-rollback")
conn = .DatabaseConnection~new("fake", 5432, "fakedb", "", .nil, "postgresql")
db = .Database~new(conn)
tx = db~transaction(.nil, identity)
op = tx~execute("DELETE FROM t WHERE id = 9")
rs = tx~rollback

call assert rs~outcome = .Error~NOTEXECUTED, "rollback outcome"
call assert rs~manifest~transactionId = "manifest-rollback", "rollback manifest tx"
call assert rs~manifest~operationCount = 1, "rollback manifest count"
call assert rs~manifest~operationIds[1] = op~operationId, "rollback operation identity"
call assert rs~manifest~operations[1]~sqlText = "DELETE FROM t WHERE id = 9", "rollback intended sql retained"

say "DATABASE ROLLBACK MANIFEST SMOKE: OK"
exit 0

assert: procedure
  use arg condition, label
  if \condition then do
    say "ASSERTION FAILED:" label
    exit 9
  end
  return

::requires "database_core.cls"
