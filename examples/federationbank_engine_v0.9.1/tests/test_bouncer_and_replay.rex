e=.FederationBankFixtures~engine
call open e,"USD-A","OA"
call open e,"USD-B","OB"
call must e~ledger~postTransfer("SEED","FB-SETTLEMENT-USD","USD-A",2000000,"USD"),"seed"
base=e~ledger~postings~items
bogus=.FederationBankCommand~new("BOGUS-1","TRANSFER","BOGUS-IDEM","CUST-001","USD-A","USD-B","USD",0,"WEB","CUST-001")
r=e~handle(bogus)
call assert r~ok=.false,"bogus denied"
call assert r~code="SECURITY_REJECTED","bogus rejected by bouncer"
call assert e~ledger~postings~items=base,"bogus produced no posting"
good=.FederationBankCommand~new("GOOD-1","TRANSFER","REPLAY-IDEM","CUST-001","USD-A","USD-B","USD",100000,"WEB","CUST-001")
call must e~handle(good),"first transfer"
afterGood=e~ledger~postings~items
replay=.FederationBankCommand~new("GOOD-2","TRANSFER","REPLAY-IDEM","CUST-001","USD-A","USD-B","USD",100000,"WEB","CUST-001")
r2=e~handle(replay)
call assert r2~ok=.true,"exact committed replay returns durable result"
call assert r2~code="REPLAY_RECOVERED","replay is recovered, not re-executed"
call assert r2~value["replaySecurityDisposition"]="REJECT","Bouncer rejects replay execution"
call assert e~ledger~postings~items=afterGood,"replay produced no posting"
say "PASS bouncer bogus rejection + durable replay recovery before ledger"
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
