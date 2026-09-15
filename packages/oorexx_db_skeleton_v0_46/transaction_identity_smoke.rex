conn = .DatabaseConnection~new("fake", 5432, "fakedb", "", .nil, "postgresql")
db = .Database~new(conn)

tx1 = db~transaction
tx2 = db~transaction

call assert tx1~transactionId <> "", "transaction id non-empty"
call assert tx2~transactionId <> "", "second transaction id non-empty"
call assert tx1~transactionId <> tx2~transactionId, "transaction ids unique"

fixed = .DatabaseTransactionIdentity~new("logical-transaction-123")
tx3 = db~transaction(.nil, fixed)
call assert tx3~transactionIdentity == fixed, "explicit identity retained"
call assert tx3~transactionId = "logical-transaction-123", "explicit id retained"

rs = tx3~rollback
call assert rs~transactionIdentity == fixed, "rollback result identity retained"
call assert rs~transactionId = "logical-transaction-123", "rollback result id retained"

say "DATABASE TRANSACTION IDENTITY SMOKE: OK"
exit 0

assert: procedure
  use arg condition, label
  if \condition then do
    say "ASSERTION FAILED:" label
    exit 9
  end
  return

::requires "database_core.cls"
