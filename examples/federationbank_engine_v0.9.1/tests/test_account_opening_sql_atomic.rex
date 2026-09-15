env = .FederationBankFixtures~freshEnvironment
e = env["engine"]
executor = env["executor"]
cmd = .FederationBankCommand~new("OPEN-ATOMIC", "OPEN_ACCOUNT", "OPEN-ATOMIC-IDEM", "CUST-ATOMIC", "", "", "USD", 0, "WEB", "online-customer", .nil, "OFFSHORE_CURRENT", "USD-ATOMIC-OPEN", "Atomic Applicant", "1979-02-03", "SW1A 1AA", "GB", "GB", "GB", "RETAIL", "STANDARD")
executor~failNext
r = e~handle(cmd)
call assert \r~ok, "injected DB write failure rejects opening"
call assert r~code = "CORE_DATABASE_ROLLBACK", "opening reports DB rollback"
call assert e~customers~customer("CUST-ATOMIC") == .nil, "customer projection unchanged after rollback"
call assert e~ledger~account("USD-ATOMIC-OPEN") == .nil, "account projection unchanged after rollback"
call assert e~ledger~postings~items = 0, "account opening DB failure has no monetary side effect"
failedSql = executor~lastCommand~stdinText
call assert failedSql~pos("BEGIN ISOLATION LEVEL SERIALIZABLE READ WRITE;") > 0, "opening DB transaction serializable"
call assert failedSql~pos("federationbank_customers") > 0, "customer row in failed transaction"
call assert failedSql~pos("federationbank_accounts") > 0, "account row in failed transaction"
call assert failedSql~pos("federationbank_account_opening_decisions") > 0, "decision evidence in failed transaction"
call assert failedSql~pos("federationbank_command_receipts") > 0, "receipt in failed transaction"
call assert failedSql~pos("COMMIT;") > 0, "single transaction compile contains commit"

/* Rollback did not consume idempotency identity; retry can commit exactly once. */
r2 = e~handle(cmd)
call must r2, "retry opening after rollback"
call assert r2~value["databaseTransactionId"] = "federationbank:OPEN-ATOMIC-IDEM", "bank idempotency key is DB transaction identity"
call assert e~customers~customer("CUST-ATOMIC") <> .nil, "customer created after successful retry"
call assert e~ledger~account("USD-ATOMIC-OPEN") <> .nil, "account created after successful retry"
call assert e~ledger~postings~items = 0, "opening remains non-monetary"
say "PASS account-opening customer+account+evidence+receipt atomic rollback and retry"
exit 0
must: procedure
  use arg r,label
  if r~ok=.false then do; say "FAIL" label r~code r~detail; exit 1; end
  return
assert: procedure
  use arg condition,label
  if \condition then do; say "FAIL" label; exit 1; end
  return
::requires "FederationBankFixtures.cls"
