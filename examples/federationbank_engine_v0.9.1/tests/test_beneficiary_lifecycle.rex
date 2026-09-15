env = .FederationBankFixtures~freshAccountEnvironment
accountEngine = .FederationBankAccountEngine~new(env["authority"])

open = .FederationBankCommand~new("BEN-OPEN-1","OPEN_ACCOUNT","BEN-OPEN-IDEM-1","CUST-BEN","","","GBP",0,"WEB","CUST-BEN",.nil,"OFFSHORE_CURRENT","BEN-GBP-1","Beneficiary Customer","1981-07-15","SW1A 1AA","GB","GB","GB","RETAIL","STANDARD")
call must accountEngine~handle(open), "open owning account"

addDetails = .directory~new
addDetails["beneficiaryId"] = "BEN-001"
addDetails["displayName"] = "Alice Example"
addDetails["accountReference"] = "GB00TEST00000001"
addDetails["bankCode"] = "TESTGB2L"
addDetails["country"] = "GB"
addDetails["currency"] = "GBP"
add = .FederationBankCommand~new("BEN-ADD-1","ADD_BENEFICIARY","BEN-ADD-IDEM-1","CUST-BEN","","","GBP",0,"WEB","CUST-BEN",.nil,"","BEN-GBP-1","","","","","","","RETAIL","STANDARD",addDetails)
r1 = accountEngine~handle(add)
call must r1, "add beneficiary"
call assert r1~value["beneficiaryId"] = "BEN-001", "beneficiary id returned"
call assert r1~value["beneficiaryStatus"] = "ACTIVE", "beneficiary active"
call assert r1~value["beneficiaryVersion"] = 1, "beneficiary version one"
call assert r1~value["corporatePolicyId"] = "FB-BENEFICIARY-LIFECYCLE", "beneficiary corporate policy provenance"
call assert r1~value["legalGenerationId"] = "FB-LEGAL-GBP", "beneficiary GBP Legal Effect provenance"
call assert r1~value["securityDisposition"] = "ALLOW", "Bouncer allowed beneficiary"

sql = env["executor"]~lastCommand~stdinText
call assert sql~pos("BEGIN ISOLATION LEVEL SERIALIZABLE READ WRITE;") > 0, "beneficiary change serializable"
call assert sql~pos("federationbank_beneficiaries") > 0, "beneficiary master in transaction"
call assert sql~pos("federationbank_beneficiary_events") > 0, "beneficiary event in transaction"
call assert sql~pos("federationbank_command_receipts") > 0, "beneficiary receipt in transaction"
call assert sql~pos("COMMIT;") > 0, "beneficiary transaction commits atomically"

amendDetails = .directory~new
amendDetails["beneficiaryId"] = "BEN-001"
amendDetails["displayName"] = "Alice Example Ltd"
amendDetails["accountReference"] = "GB00TEST00000002"
amendDetails["bankCode"] = "TESTGB2L"
amendDetails["country"] = "GB"
amendDetails["currency"] = "GBP"
amend = .FederationBankCommand~new("BEN-AMEND-1","AMEND_BENEFICIARY","BEN-AMEND-IDEM-1","CUST-BEN","","","GBP",0,"WEB","CUST-BEN",.nil,"","BEN-GBP-1","","","","","","","RETAIL","STANDARD",amendDetails)
r2 = accountEngine~handle(amend)
call must r2, "amend beneficiary"
call assert r2~value["beneficiaryVersion"] = 2, "beneficiary version two"
call assert r2~value["beneficiaryDisplayName"] = "Alice Example Ltd", "beneficiary amendment projected"

suspendDetails = .directory~new
suspendDetails["beneficiaryId"] = "BEN-001"
suspend = .FederationBankCommand~new("BEN-SUSPEND-1","SUSPEND_BENEFICIARY","BEN-SUSPEND-IDEM-1","CUST-BEN","","","GBP",0,"WEB","CUST-BEN",.nil,"","BEN-GBP-1","","","","","","","RETAIL","STANDARD",suspendDetails)
r3 = accountEngine~handle(suspend)
call must r3, "suspend beneficiary"
call assert r3~value["beneficiaryStatus"] = "SUSPENDED", "beneficiary suspended"
call assert r3~value["beneficiaryVersion"] = 3, "beneficiary version three"
current = env["beneficiaries"]~beneficiary("CUST-BEN","BEN-001")
call assert current <> .nil, "beneficiary retained in registry"
call assert current~status = "SUSPENDED", "registry holds suspended state"
call assert current~version = 3, "registry holds current version"

/* A fresh Account authority sharing the DB fixture must recover the original
   result payload rather than re-run the ADD against current suspended state. */
fresh = .FederationBankFixtures~buildAccountAuthority(env["database"], .false, env["external"])
replay = fresh~handle(add)
call must replay, "durable beneficiary replay"
call assert replay~code = "REPLAY_RECOVERED", "beneficiary receipt recovered after worker restart"
call assert replay~value["beneficiaryId"] = "BEN-001", "recovered operation-specific beneficiary id"
call assert replay~value["beneficiaryStatus"] = "ACTIVE", "recovered original beneficiary state"
call assert replay~value["beneficiaryVersion"] = 1, "recovered original beneficiary version"

say "PASS Account Engine beneficiary add/amend/suspend + durable receipt payload"
exit 0
must: procedure
  use arg r,label
  if r~ok=.false then do; say "FAIL" label r~code r~detail; exit 1; end
  return
assert: procedure
  use arg condition,label
  if \condition then do; say "FAIL" label; exit 1; end
  return
::requires "FederationBankServices.cls"
::requires "FederationBankFixtures.cls"
