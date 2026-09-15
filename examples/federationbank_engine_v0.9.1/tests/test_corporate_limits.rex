e=.FederationBankFixtures~engine
call open e,"USD-L1","OL1"
call open e,"USD-L2","OL2"
call must e~ledger~postTransfer("SEED-L","FB-SETTLEMENT-USD","USD-L1",20000000,"USD"),"seed"
base=e~ledger~postings~items
large=.FederationBankCommand~new("LARGE","TRANSFER","LARGE-IDEM","CUST-001","USD-L1","USD-L2","USD",5000001,"WEB","CUST-001")
r=e~handle(large)
call assert r~ok=.false,"large denied"
call assert r~code="CORPORATE_POLICY_DENIED","large denied by corporate policy"
call assert r~value["ruleId"]="USD-RETAIL-WEB","limit rule provenance"
call assert r~value["reason"]="PER_TRANSACTION_LIMIT","per tx reason"
call assert e~ledger~postings~items=base,"limit denial no posting"
call must e~handle(.FederationBankCommand~new("D1","TRANSFER","D1","CUST-001","USD-L1","USD-L2","USD",4000000,"WEB","CUST-001")),"daily first"
call must e~handle(.FederationBankCommand~new("D2","TRANSFER","D2","CUST-001","USD-L1","USD-L2","USD",4000000,"WEB","CUST-001")),"daily second"
beforeDailyReject=e~ledger~postings~items
r2=e~handle(.FederationBankCommand~new("D3","TRANSFER","D3","CUST-001","USD-L1","USD-L2","USD",3000000,"WEB","CUST-001"))
call assert r2~ok=.false,"daily denied"
call assert r2~code="CORPORATE_POLICY_DENIED","daily corporate denial"
call assert r2~value["reason"]="DAILY_LIMIT","daily limit reason"
call assert r2~value["policyId"]="FB-CUSTOMER-TXN-LIMITS","policy provenance present"
call assert e~ledger~postings~items=beforeDailyReject,"daily denial no posting"
say "PASS corporate customer limits are policy-owned"
exit 0
open: procedure
  use arg e,id,idem
  c=.FederationBankCommand~new("CMD-"||idem,"OPEN_ACCOUNT",idem,"CUST-001","","","USD",0,"WEB","CUST-001",.nil,"OFFSHORE_CURRENT",id)
  call must e~handle(c),"open "||id
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
