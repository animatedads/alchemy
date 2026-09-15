v=.VectorMeridianMarkets~new
x=.VMMInstitutionalSyntheticService~new(v)
cp=.VMMInstitutionalCounterparty~new("AJI","ALL_JAPAN_INSURANCE","REL-AJI","JP","KYC-AJI","ISDA-AJI","CSA-AJI","VMM-ONBOARD")
x~registerCounterparty(cp)
x~setRiskPolicy(.VMMSyntheticRiskPolicy~new("RISK-JPY","JPY",100000000000,50000000000,100,"RISK-POL"),"VMM-RISK")
p=.VMMPortfolioReferencePosition~new("P-DISP","AJI","JGB-DISP","JAPAN_GOVERNMENT","SOVEREIGN_BOND","JPY",10000000,"ALL_JAPAN_INSURANCE","","BOOK-DISP","","VAL-DISP")
s=.VMMPortfolioSnapshot~new("SNAP-DISP","AJI","ALL_JAPAN_INSURANCE","JPY","20260828",.array~of(p),"POS-DISP","","VMM-PORTFOLIO")
x~registerPortfolioSnapshot(s)
x~createOffer("OFF-DISP","REQ-DISP","AJI","SNAP-DISP","JPY",10000000,5,25,100000,"20260901","20310831","20260828T140000","20260828T132100","MODEL-DISP","MKT-DISP","RISK-DISP")
k=x~acceptOffer("CON-DISP","OFF-DISP","20260828T132200","ALL_JAPAN_INSURANCE","AJI-SIGNER")

d=.VMMInstitutionalDefaultCloseoutService~new(x)
d~setPolicy(.VMMSyntheticDefaultPolicy~new("DEF-JPY","JPY",2,1,3,"ISDA-CLOSEOUT","DEF-POL"),"VMM-LEGAL")
ops=.VMMCloseoutOperationsService~new(d)
ops~setPolicy(.VMMCloseoutOperationsPolicy~new("OPS-JPY","JPY",2,3,"INDEPENDENT-VALUATION-AGENT","LEGAL-NETTING-OPINION-POLICY","OPS-POL"),"VMM-LEGAL")
ev=d~declareDefault("DEF-DISP",k~contractId,"INSOLVENCY","ALL_JAPAN_INSURANCE","2026-10-06","2026-10-06","INSOLVENCY-EVID","VMM-LEGAL")
d~assessUncured("UNCURED-DISP",ev~eventId,"2026-10-07","UNCURED-EVID","VMM-LEGAL")
t=d~electTermination("TERM-DISP",ev~eventId,"VECTOR_MERIDIAN_MARKETS_LTD","2026-10-07","TERM-NOTICE","ORIGINAL-VALUATION-AGENT","VMM-LEGAL")
co=d~determineCloseout("CLOSE-DISP",t~terminationId,2000000,"2026-10-10","ISDA-METHOD","MKT-ORIGINAL","CSA-NETTING-EVID","VMM-VALUATION-CONTROL")
call assertNear 2000000,co~grossAmountToVMM,0.01,"original close-out determination fixed"

disp=ops~disputeCloseout("DISP-1",co~closeoutId,"ALL_JAPAN_INSURANCE",1400000,"2026-10-11","AJI-DISPUTE-EVID","AJI-LEGAL")
call assertEq "OPEN",disp~state,"dispute open"
blocked=.false
signal on syntax name earlySettle
ignore=d~settleCloseout("SETTLE-TOO-EARLY",co~closeoutId,"2026-10-11","PAYMENT-EVID","VMM-TREASURY")
signal off syntax
raise syntax 88.900 array("ASSERT_DISPUTED_CLOSEOUT_SETTLED")
earlySettle:
  blocked=.true; signal off syntax
call assertTrue blocked,"unresolved dispute blocks direct settlement"

badAgent=.false
signal on syntax name wrongAgent
ignore=ops~resolveDispute("RES-BAD",disp~disputeId,1600000,"2026-10-12","ORIGINAL-VALUATION-AGENT","METHOD-BAD","MKT-BAD","VMM-LEGAL")
signal off syntax
raise syntax 88.900 array("ASSERT_ORIGINAL_AGENT_ACCEPTED_AS_FALLBACK")
wrongAgent:
  badAgent=.true; signal off syntax
call assertTrue badAgent,"original valuation agent cannot resolve its own disputed amount"

res=ops~resolveDispute("RES-1",disp~disputeId,1600000,"2026-10-12","INDEPENDENT-VALUATION-AGENT","METHOD-FALLBACK","MKT-FALLBACK","VMM-LEGAL")
call assertNear 1600000,res~finalGrossAmountToVMM,0.01,"fallback agent fixes revised legal amount"
f=ops~finalizeCloseout("FINAL-1",co~closeoutId,"2026-10-12","VMM-LEGAL")
call assertEq "DISPUTE_RESOLUTION",f~basis,"finalization records dispute-resolution basis"
call assertNear 1600000,f~netAmountToVMM,0.01,"finalized net amount uses fallback resolution"
call assertNear 2000000,co~grossAmountToVMM,0.01,"original determination remains immutable"
settle=d~settleCloseout("SETTLE-DISP",co~closeoutId,"2026-10-13","BANK-PAYMENT-DISP","VMM-TREASURY")
call assertEq f~finalizationId,settle~finalizationId,"settlement binds exact finalization"
call assertNear 1600000,settle~amount,0.01,"settlement uses finalized amount, not original determination"
call assertEq "ALL_JAPAN_INSURANCE",settle~payerEntity,"client pays VMM finalized receivable"
call assertEq "VECTOR_MERIDIAN_MARKETS_LTD",settle~payeeEntity,"VMM is final settlement payee"
say "PASS test_closeout_dispute_fallback_finalization"
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
