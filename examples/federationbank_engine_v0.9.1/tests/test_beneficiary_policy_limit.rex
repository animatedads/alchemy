env = .FederationBankFixtures~freshAccountEnvironment
a = env["authority"]
open = .FederationBankCommand~new("BL-OPEN-1","OPEN_ACCOUNT","BL-OPEN-IDEM-1","CUST-BL","","","USD",0,"WEB","CUST-BL",.nil,"OFFSHORE_CURRENT","BL-USD-1","Limit Customer","1983-12-01","SW1A 1AA","GB","GB","GB","RETAIL","STANDARD")
call must a~handle(open), "open owning account"

do i=1 to 3
  d = .directory~new
  d["beneficiaryId"] = "BL-BEN-" || i
  d["displayName"] = "Recipient " || i
  d["accountReference"] = "US-TEST-" || i
  d["bankCode"] = "TESTUS"
  d["country"] = "US"
  d["currency"] = "USD"
  cmd = .FederationBankCommand~new("BL-ADD-"||i,"ADD_BENEFICIARY","BL-IDEM-"||i,"CUST-BL","","","USD",0,"WEB","CUST-BL",.nil,"","BL-USD-1","","","","","","","RETAIL","STANDARD",d)
  r = a~handle(cmd)
  if i < 3 then call must r, "beneficiary within corporate limit " || i
  else do
    call assert r~ok = .false, "third active beneficiary denied"
    call assert r~code = "CORPORATE_POLICY_DENIED", "limit denial comes from Institutional Policy"
    call assert r~value["reason"] = "ACTIVE_BENEFICIARY_LIMIT", "policy denial reason retained"
    call assert r~value["policyId"] = "FB-BENEFICIARY-LIFECYCLE", "policy identity retained"
  end
end
call assert env["beneficiaries"]~activeCount("CUST-BL") = 2, "only two active beneficiaries exist"
call assert env["beneficiaries"]~beneficiary("CUST-BL","BL-BEN-3") == .nil, "denied beneficiary not persisted"

say "PASS beneficiary customer limit is Institutional Policy-owned"
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
