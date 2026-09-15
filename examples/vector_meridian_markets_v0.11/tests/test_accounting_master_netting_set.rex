v=.VectorMeridianMarkets~new
x=.VMMInstitutionalSyntheticService~new(v)
cp=.VMMInstitutionalCounterparty~new("AJI","ALL_JAPAN_INSURANCE","REL-AJI","JP","KYC-AJI","ISDA-AJI-2002","CSA-AJI","VMM-ONBOARD")
x~registerCounterparty(cp)
x~setRiskPolicy(.VMMSyntheticRiskPolicy~new("RISK-JPY","JPY",1000000000000,500000000000,100,"RISK-POL"),"VMM-RISK")
p=.VMMPortfolioReferencePosition~new("P-ANET","AJI","JGB-ANET","JAPAN_GOVERNMENT","SOVEREIGN_BOND","JPY",100000000,"ALL_JAPAN_INSURANCE","","BOOK-ANET","","VAL-ANET")
s=.VMMPortfolioSnapshot~new("SNAP-ANET","AJI","ALL_JAPAN_INSURANCE","JPY","20260828",.array~of(p),"POS-ANET","","VMM-PORTFOLIO")
x~registerPortfolioSnapshot(s)
x~createOffer("OFF-A1","REQ-A1","AJI","SNAP-ANET","JPY",10000000,5,25,100000,"20260901","20310831","20260828T140000","20260828T132100","MODEL-A1","MKT-A1","RISK-A1")
k1=x~acceptOffer("CON-A1","OFF-A1","20260828T132200","ALL_JAPAN_INSURANCE","AJI-SIGNER")
x~createOffer("OFF-A2","REQ-A2","AJI","SNAP-ANET","JPY",10000000,5,25,100000,"20260901","20310831","20260828T140100","20260828T132300","MODEL-A2","MKT-A2","RISK-A2")
k2=x~acceptOffer("CON-A2","OFF-A2","20260828T132400","ALL_JAPAN_INSURANCE","AJI-SIGNER")

d=.VMMInstitutionalDefaultCloseoutService~new(x)
d~setPolicy(.VMMSyntheticDefaultPolicy~new("DEF-JPY","JPY",2,1,3,"ISDA-CLOSEOUT","DEF-POL"),"VMM-LEGAL")
ops=.VMMCloseoutOperationsService~new(d)
ops~setPolicy(.VMMCloseoutOperationsPolicy~new("OPS-JPY","JPY",0,3,"INDEPENDENT-VALUATION-AGENT","JP-NETTING-OPINION-POLICY","OPS-POL"),"VMM-LEGAL")

ev1=d~declareDefault("DEF-A1",k1~contractId,"INSOLVENCY","ALL_JAPAN_INSURANCE","2026-10-06","2026-10-06","INSOLVENCY-A1","VMM-LEGAL")
d~assessUncured("UNCURED-A1",ev1~eventId,"2026-10-07","UNCURED-A1","VMM-LEGAL")
t1=d~electTermination("TERM-A1",ev1~eventId,"VECTOR_MERIDIAN_MARKETS_LTD","2026-10-07","TERM-A1","VAL-AGENT-A1","VMM-LEGAL")
co1=d~determineCloseout("CLOSE-A1",t1~terminationId,3000000,"2026-10-10","ISDA-METHOD","MKT-A1","CSA-A1","VMM-VALUATION")
f1=ops~finalizeCloseout("FINAL-A1",co1~closeoutId,"2026-10-11","VMM-LEGAL")
ev2=d~declareDefault("DEF-A2",k2~contractId,"INSOLVENCY","ALL_JAPAN_INSURANCE","2026-10-06","2026-10-06","INSOLVENCY-A2","VMM-LEGAL")
d~assessUncured("UNCURED-A2",ev2~eventId,"2026-10-07","UNCURED-A2","VMM-LEGAL")
t2=d~electTermination("TERM-A2",ev2~eventId,"VECTOR_MERIDIAN_MARKETS_LTD","2026-10-07","TERM-A2","VAL-AGENT-A2","VMM-LEGAL")
co2=d~determineCloseout("CLOSE-A2",t2~terminationId,-1000000,"2026-10-10","ISDA-METHOD","MKT-A2","CSA-A2","VMM-VALUATION")
f2=ops~finalizeCloseout("FINAL-A2",co2~closeoutId,"2026-10-11","VMM-LEGAL")
ns=ops~createNettingSet("NETSET-ACC",.array~of(k1~contractId,k2~contractId),"ENGLISH_LAW","LEGAL-OPINION-ACC","ISDA-NETTING-ELECTION-ACC","2026-10-11","VMM-LEGAL")
nd=ops~determineNettingSet("NETDET-ACC",ns~nettingSetId,"2026-10-12","NET-CALC-ACC","VMM-VALUATION")
settle=ops~settleNettingSet("NETSETTLE-ACC",ns~nettingSetId,"2026-10-13","BANK-NET-ACC","VMM-TREASURY")

eng=.AccountingEngine~new("VECTOR_MERIDIAN_MARKETS_LTD","VMM-STAT","ENTITY_GAAP")
.VMMAccountingPolicy~configureEngine(eng,.AccountingPeriod~new("2026-10","2026-10-01","2026-10-31"))
acct=.VMMAccountingService~new(v,eng)
r1=acct~postCloseoutFinalization(f1,"2026-10-11","2026-10")
r2=acct~postCloseoutFinalization(f2,"2026-10-11","2026-10")
call assertTrue r1~ok & r2~ok,"member finalizations recognized before legal set-off cash settlement"
call assertEq 300000000,acct~book~balance("1500","JPY")~netDebitMinor,"gross close-out receivable remains visible before netting settlement"
call assertEq -100000000,acct~book~balance("2400","JPY")~netDebitMinor,"gross close-out payable remains visible before netting settlement"
rs=acct~postNettingSetSettlement(settle,nd,ns,"2026-10-13","2026-10")
call assertTrue rs~ok,"Accounting Core consumes evidence-backed master-agreement net settlement"
call assertEq 0,acct~book~balance("1500","JPY")~netDebitMinor,"legal net settlement clears member receivables"
call assertEq 0,acct~book~balance("2400","JPY")~netDebitMinor,"legal net settlement clears member payables"
call assertEq 200000000,acct~book~balance("1000","JPY")~netDebitMinor,"only the 2m legal net amount moves cash"
call assertEq "vmm-accounting-artifact/0.11:master-netting-settled",rs~entry~policyIdentity,"netting settlement freezes exact policy identity"
call assertEq "ALL_JAPAN_INSURANCE",rs~entry~counterpartyEntityId,"netting counterparty remains evidence dimension, not book owner"
say "PASS test_accounting_master_netting_set"
exit 0
::routine assertEq
  use strict arg expected,actual,label
  if expected<>actual then raise syntax 88.900 array("ASSERT_EQ",label,"expected",expected,"actual",actual)
::routine assertTrue
  use strict arg value,label
  if \value then raise syntax 88.900 array("ASSERT_TRUE",label)
::requires "VMMAccounting.cls"
