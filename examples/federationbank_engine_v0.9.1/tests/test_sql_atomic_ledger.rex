e = .FederationBankFixtures~engine
call open e, "USD-ATOMIC-SRC", "OPEN-ATOMIC-SRC"
call open e, "USD-ATOMIC-DST", "OPEN-ATOMIC-DST"
call must e~ledger~postTransfer("SEED-ATOMIC", "FB-SETTLEMENT-USD", "USD-ATOMIC-SRC", 2000000, "USD"), "seed"
call assert e~ledger~durable, "fixture ledger uses SQL transaction store"

executor = e~ledger~store~database~executor
beforeCount = e~ledger~postings~items
beforeSource = e~ledger~balanceMinor("USD-ATOMIC-SRC")
beforeTarget = e~ledger~balanceMinor("USD-ATOMIC-DST")
executor~failNext
cmd = .FederationBankCommand~new("ATOMIC-FAIL-CMD", "TRANSFER", "ATOMIC-FAIL-TX", "CUST-001", "USD-ATOMIC-SRC", "USD-ATOMIC-DST", "USD", 250000, "WEB", "CUST-001")
r = e~handle(cmd)
call assert r~ok = .false, "synthetic SQL failure rejected transfer"
call assert r~code = "LEDGER_DATABASE_ROLLBACK", "failure reported as database rollback"
call assert e~ledger~postings~items = beforeCount, "no debit or credit projected after failed SQL transaction"
call assert e~ledger~balanceMinor("USD-ATOMIC-SRC") = beforeSource, "source unchanged after rollback"
call assert e~ledger~balanceMinor("USD-ATOMIC-DST") = beforeTarget, "target unchanged after rollback"
call assert e~ledger~hasTransaction("ATOMIC-FAIL-TX") = .false, "failed transaction is not ledger truth"
failedCommand = executor~lastCommand
sql = failedCommand~stdinText
call assert e~receipt("ATOMIC-FAIL-TX") == .nil, "failed transaction has no success receipt"
call assert sql~pos("BEGIN ISOLATION LEVEL SERIALIZABLE READ WRITE;") > 0, "serializable read-write database transaction"
call assert sql~pos("federationbank_transactions") > 0, "transaction header in same SQL unit"
call assert sql~pos("federationbank_ledger_postings") > 0, "posting writes in same SQL unit"
call assert sql~pos("USD-ATOMIC-SRC") > 0, "debit leg in compiled SQL"
call assert sql~pos("USD-ATOMIC-DST") > 0, "credit leg in compiled SQL"
call assert sql~pos("federationbank_transaction_decisions") > 0, "policy/legal/security provenance in same SQL unit"
call assert sql~pos("federationbank_command_receipts") > 0, "durable replay receipt in same SQL unit"
call assert sql~pos("COMMIT;") > 0, "single commit closes banking write unit"

/* A rollback did not consume the banking idempotency key. A deliberate retry of
   the same logical bank transaction can now commit once. */
r2 = e~handle(cmd)
call must r2, "retry same logical transaction after rollback"
call assert r2~value["databaseTransactionId"] = "federationbank:ATOMIC-FAIL-TX", "bank id is database transaction identity"
call assert e~ledger~transactionPostings("ATOMIC-FAIL-TX")~items = 2, "retry commits exactly two balanced legs"
pair = e~ledger~transactionPostings("ATOMIC-FAIL-TX")
call assert pair[1]~amountMinor + pair[2]~amountMinor = 0, "committed legs balance to zero"
say "PASS SQL atomic ledger rollback + retry identity"
exit 0

open: procedure
  use arg e, accountId, idem
  c=.FederationBankCommand~new("CMD-" || idem,"OPEN_ACCOUNT",idem,"CUST-001","","","USD",0,"WEB","CUST-001",.nil,"OFFSHORE_CURRENT",accountId)
  call must e~handle(c), "open " || accountId
  return
must: procedure
  use arg r,label
  if r~ok=.false then do; say "FAIL" label r~code r~detail; exit 1; end
  return
assert: procedure
  use arg condition,label
  if \condition then do; say "FAIL" label; exit 1; end
  return
::requires "FederationBankFixtures.cls"
