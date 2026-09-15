env = .FederationBankFixtures~freshEnvironment
e = env["engine"]
external = env["external"]
civic = external["civicTransport"]
credit = external["creditAgency"]
cmd = .FederationBankCommand~new("OPEN-NEW-1", "OPEN_ACCOUNT", "OPEN-NEW-IDEM-1", "CUST-NEW-1", "", "", "GBP", 0, "WEB", "online-customer", .nil, "OFFSHORE_CURRENT", "GBP-NEW-1", "Ada Example", "1988-04-12", "SW1A 1AA", "GB", "GB", "GB", "RETAIL", "STANDARD")
r = e~handle(cmd)
call must r, "new customer account open"
call assert r~value["outcome"] = "ACCEPTED", "opening accepted"
call assert e~customers~customer("CUST-NEW-1") <> .nil, "customer created only by engine"
call assert e~ledger~account("GBP-NEW-1") <> .nil, "account created by engine"
call assert civic~calls = 1, "CivicPort called exactly once"
call assert credit~calls = 1, "credit agency called exactly once"
call assert r~value["addressContractGeneration"] = "civic.postcode.lookup/0.1", "CivicPort contract provenance"
call assert r~value["addressMappingGeneration"] = "postcodes.io.postcode/0.2", "CivicPort mapping provenance"
call assert r~value["creditBureauReference"] <> "", "credit bureau reference retained"
call assert r~value["corporatePolicyId"] = "FB-ACCOUNT-OPENING", "opening decision owned by institutional policy"
call assert r~value["legalGenerationId"] = "FB-LEGAL-GBP", "GBP legal generation selected"
sql = env["executor"]~lastCommand~stdinText
call assert sql~pos("BEGIN ISOLATION LEVEL SERIALIZABLE READ WRITE;") > 0, "opening is serializable write transaction"
call assert sql~pos("federationbank_customers") > 0, "customer write in transaction"
call assert sql~pos("federationbank_accounts") > 0, "account write in transaction"
call assert sql~pos("federationbank_account_opening_decisions") > 0, "opening evidence in transaction"
call assert sql~pos("federationbank_command_receipts") > 0, "durable receipt in transaction"
call assert sql~pos("COMMIT;") > 0, "opening transaction commits once"
say "PASS engine-owned account opening CivicPort + credit agency + policy/legal/security + SQL"
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
