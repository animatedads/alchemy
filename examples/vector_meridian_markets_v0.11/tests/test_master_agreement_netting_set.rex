v=.VectorMeridianMarkets~new
x=.VMMInstitutionalSyntheticService~new(v)
cp=.VMMInstitutionalCounterparty~new("AJI","ALL_JAPAN_INSURANCE","REL-AJI","JP","KYC-AJI","ISDA-AJI-2002","CSA-AJI","VMM-ONBOARD")
x~registerCounterparty(cp)
x~setRiskPolicy(.VMMSyntheticRiskPolicy~new("RISK-JPY","JPY",1000000000000,500000000000,100,"RISK-POL"),"VMM-RISK")
p=.VMMPortfolioReferencePosition~new("P-NETSET","AJI","JGB-NETSET","JAPAN_GOVERNMENT","SOVEREIGN_BOND","JPY",100000000,"ALL_JAPAN_INSURANCE","","BOOK-NETSET","","VAL-NETSET")
s=.VMMPortfolioSnapshot~new("SNAP-NETSET","AJI","ALL_JAPAN_INSURANCE","JPY","20260828",.array~of(p),"POS-NETSET","","VMM-PORTFOLIO")
x~registerPortfolioSnapshot(s)
x~createOffer("OFF-N1","REQ-N1","AJI","SNAP-NETSET","JPY",10000000,5,25,100000,"20260901","20310831","20260828T140000","20260828T132100","MODEL-N1","MKT-N1","RISK-N1")
k1=x~acceptOffer("CON-N1","OFF-N1","20260828T132200","ALL_JAPAN_INSURANCE","AJI-SIGNER")
x~createOffer("OFF-N2","REQ-N2","AJI","SNAP-NETSET","JPY",10000000,5,25,100000,"20260901","20310831","20260828T140100","20260828T132300","MODEL-N2","MKT-N2","RISK-N2")
k2=x~acceptOffer("CON-N2","OFF-N2","20260828T132400","ALL_JAPAN_INSURANCE","AJI-SIGNER")

d=.VMMInstitutionalDefaultCloseoutService~new(x)
d~setPolicy(.VMMSyntheticDefaultPolicy~new("DEF-JPY","JPY",2,1,3,"ISDA-CLOSEOUT","DEF-POL"),"VMM-LEGAL")
ops=.VMMCloseoutOperationsService~new(d)
ops~setPolicy(.VMMCloseoutOperationsPolicy~new("OPS-JPY","JPY",0,3,"INDEPENDENT-VALUATION-AGENT","JP-NETTING-OPINION-POLICY","OPS-POL"),"VMM-LEGAL")

ev1=d~declareDefault("DEF-N1",k1~contractId,"INSOLVENCY","ALL_JAPAN_INSURANCE","2026-10-06","2026-10-06","INSOLVENCY-N1","VMM-LEGAL")
d~assessUncured("UNCURED-N1",ev1~eventId,"2026-10-07","UNCURED-N1","VMM-LEGAL")
t1=d~electTermination("TERM-N1",ev1~eventId,"VECTOR_MERIDIAN_MARKETS_LTD","2026-10-07","TERM-N1","VAL-AGENT-N1","VMM-LEGAL")
co1=d~determineCloseout("CLOSE-N1",t1~terminationId,3000000,"2026-10-10","ISDA-METHOD","MKT-N1","CSA-NET-N1","VMM-VALUATION")
f1=ops~finalizeCloseout("FINAL-N1",co1~closeoutId,"2026-10-11","VMM-LEGAL")

ev2=d~declareDefault("DEF-N2",k2~contractId,"INSOLVENCY","ALL_JAPAN_INSURANCE","2026-10-06","2026-10-06","INSOLVENCY-N2","VMM-LEGAL")
d~assessUncured("UNCURED-N2",ev2~eventId,"2026-10-07","UNCURED-N2","VMM-LEGAL")
t2=d~electTermination("TERM-N2",ev2~eventId,"VECTOR_MERIDIAN_MARKETS_LTD","2026-10-07","TERM-N2","VAL-AGENT-N2","VMM-LEGAL")
co2=d~determineCloseout("CLOSE-N2",t2~terminationId,-1000000,"2026-10-10","ISDA-METHOD","MKT-N2","CSA-NET-N2","VMM-VALUATION")
f2=ops~finalizeCloseout("FINAL-N2",co2~closeoutId,"2026-10-11","VMM-LEGAL")

ns=ops~createNettingSet("NETSET-AJI-1",.array~of(k1~contractId,k2~contractId),"ENGLISH_LAW","LEGAL-OPINION-AJI-ISDA-2002","ISDA-CLOSEOUT-NETTING-ELECTION-AJI","2026-10-11","VMM-LEGAL")
call assertEq "ISDA-AJI-2002",ns~masterAgreementRef,"netting set freezes exact common master agreement"
blocked=.false
signal on syntax name noSeparateSettlement
ignore=d~settleCloseout("SETTLE-N1-SEPARATE",co1~closeoutId,"2026-10-12","BANK-PAYMENT-N1","VMM-TREASURY")
signal off syntax
raise syntax 88.900 array("ASSERT_INDIVIDUAL_SETTLEMENT_ALLOWED_AFTER_NETTING_SET")
noSeparateSettlement:
  blocked=.true; signal off syntax
call assertTrue blocked,"member close-out cannot settle separately once legal netting set is fixed"
nd=ops~determineNettingSet("NETDET-AJI-1",ns~nettingSetId,"2026-10-12","NET-CALC-EVID","VMM-VALUATION-CONTROL")
call assertNear 3000000,nd~totalReceivable,0.01,"netting keeps gross receivable evidence"
call assertNear 1000000,nd~totalPayable,0.01,"netting keeps gross payable evidence"
call assertNear 2000000,nd~netAmountToVMM,0.01,"legal set-off produces one VMM receivable"
settle=ops~settleNettingSet("NETSETTLE-AJI-1",ns~nettingSetId,"2026-10-13","BANK-NET-SETTLEMENT-AJI","VMM-TREASURY")
call assertNear 2000000,settle~amount,0.01,"single cash settlement equals legal net amount"
call assertEq "ALL_JAPAN_INSURANCE",settle~payerEntity,"AJI pays net amount to VMM"
call assertEq "VECTOR_MERIDIAN_MARKETS_LTD",settle~payeeEntity,"VMM receives net-set cash"
call assertTrue ops~isCloseoutCashSettled(co1~closeoutId),"first member marked cash-settled by aggregate payment"
call assertTrue ops~isCloseoutCashSettled(co2~closeoutId),"second member marked cash-settled by aggregate payment"
call assertNear 0,d~effectiveCashCollateralPosted(k1~contractId),0.01,"default service sees aggregate net settlement as close-out cash settlement"
say "PASS test_master_agreement_netting_set"
exit 0
::routine assertEq
  use strict arg expected,actual,label
  if expected<>actual then raise syntax 88.900 array("ASSERT_EQ",label,"expected",expected,"actual",actual)
::routine assertNear
  use strict arg expected,actual,tolerance,label
  if abs(expected-actual)>tolerance then raise syntax 88.900 array("ASSERT_NEAR",label,"expected",expected,"actual",actual)
::routine assertTrue
  use strict arg value,label
  if \value then raise syntax 88.900 array("ASSERT_TRUE",label)
::requires "VMMCloseoutOperations.cls"
