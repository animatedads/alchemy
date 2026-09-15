env = .FederationBankFixtures~freshAccountEnvironment
authority = env["authority"]
open = .FederationBankCommand~new("BA-OPEN-1","OPEN_ACCOUNT","BA-OPEN-IDEM-1","CUST-BA","","","EUR",0,"WEB","CUST-BA",.nil,"OFFSHORE_CURRENT","BA-EUR-1","Atomic Beneficiary Customer","1977-03-02","SW1A 1AA","GB","GB","GB","RETAIL","STANDARD")
call must authority~handle(open), "open owning account"

d = .directory~new
d["beneficiaryId"] = "BA-BEN-1"
d["displayName"] = "Rollback Recipient"
d["accountReference"] = "DE00ROLLBACK0001"
d["bankCode"] = "TESTDEFF"
d["country"] = "DE"
d["currency"] = "EUR"
cmd = .FederationBankCommand~new("BA-ADD-1","ADD_BENEFICIARY","BA-ADD-IDEM-1","CUST-BA","","","EUR",0,"WEB","CUST-BA",.nil,"","BA-EUR-1","","","","","","","RETAIL","STANDARD",d)

env["executor"]~failNext
failed = authority~manageBeneficiary(cmd)
call assert failed~ok = .false, "injected beneficiary DB failure rejected"
call assert failed~code = "BENEFICIARY_DATABASE_ROLLBACK", "beneficiary reports DB rollback"
call assert env["beneficiaries"]~beneficiary("CUST-BA","BA-BEN-1") == .nil, "in-memory beneficiary unchanged after rollback"
sql = env["executor"]~lastCommand~stdinText
call assert sql~pos("federationbank_beneficiaries") > 0, "failed transaction contains beneficiary master"
call assert sql~pos("federationbank_beneficiary_events") > 0, "failed transaction contains beneficiary audit event"
call assert sql~pos("federationbank_command_receipts") > 0, "failed transaction contains durable receipt"
call assert sql~pos("COMMIT;") > 0, "failed compiled unit was one transaction"

retry = authority~manageBeneficiary(cmd)
call must retry, "retry same logical beneficiary change after rollback"
call assert retry~value["databaseTransactionId"] = "federationbank:beneficiary:BA-ADD-IDEM-1", "beneficiary idempotency key anchors DB identity"
call assert env["beneficiaries"]~beneficiary("CUST-BA","BA-BEN-1") <> .nil, "beneficiary projected only after commit"

say "PASS beneficiary SQL atomic rollback + retry identity"
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
