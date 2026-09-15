v=.VectorMeridianMarkets~new
x=.VMMInstitutionalSyntheticService~new(v)
cp=.VMMInstitutionalCounterparty~new("AJI","ALL_JAPAN_INSURANCE","REL-AJI","JP","KYC-AJI","ISDA-AJI","CSA-AJI","VMM-ONBOARD")
x~registerCounterparty(cp)
x~setRiskPolicy(.VMMSyntheticRiskPolicy~new("RISK-JPY","JPY",100000000000,50000000000,100,"RISK-POL"),"VMM-RISK")
p=.VMMPortfolioReferencePosition~new("P-WIN","AJI","JGB-WIN","JAPAN_GOVERNMENT","SOVEREIGN_BOND","JPY",10000000,"ALL_JAPAN_INSURANCE","","BOOK-WIN","","VAL-WIN")
s=.VMMPortfolioSnapshot~new("SNAP-WIN","AJI","ALL_JAPAN_INSURANCE","JPY","20260828",.array~of(p),"POS-WIN","","VMM-PORTFOLIO")
x~registerPortfolioSnapshot(s)
x~createOffer("OFF-WIN","REQ-WIN","AJI","SNAP-WIN","JPY",10000000,5,25,100000,"20260901","20310831","20260828T140000","20260828T132100","MODEL-WIN","MKT-WIN","RISK-WIN")
k=x~acceptOffer("CON-WIN","OFF-WIN","20260828T132200","ALL_JAPAN_INSURANCE","AJI-SIGNER")
d=.VMMInstitutionalDefaultCloseoutService~new(x)
d~setPolicy(.VMMSyntheticDefaultPolicy~new("DEF-JPY","JPY",2,1,3,"ISDA-CLOSEOUT","DEF-POL"),"VMM-LEGAL")
ops=.VMMCloseoutOperationsService~new(d)
ops~setPolicy(.VMMCloseoutOperationsPolicy~new("OPS-JPY","JPY",2,3,"INDEPENDENT-VALUATION-AGENT","LEGAL-NETTING-OPINION-POLICY","OPS-POL"),"VMM-LEGAL")
ev=d~declareDefault("DEF-WIN",k~contractId,"INSOLVENCY","ALL_JAPAN_INSURANCE","2026-10-06","2026-10-06","INSOLVENCY-EVID","VMM-LEGAL")
d~assessUncured("UNCURED-WIN",ev~eventId,"2026-10-07","UNCURED-EVID","VMM-LEGAL")
t=d~electTermination("TERM-WIN",ev~eventId,"VECTOR_MERIDIAN_MARKETS_LTD","2026-10-07","TERM-NOTICE","ORIGINAL-VALUATION-AGENT","VMM-LEGAL")
co=d~determineCloseout("CLOSE-WIN",t~terminationId,-750000,"2026-10-10","ISDA-METHOD","MKT-WIN","CSA-NETTING-EVID","VMM-VALUATION")
blocked=.false
signal on syntax name tooSoon
ignore=ops~finalizeCloseout("FINAL-WIN-EARLY",co~closeoutId,"2026-10-12","VMM-LEGAL")
signal off syntax
raise syntax 88.900 array("ASSERT_FINALIZED_INSIDE_DISPUTE_WINDOW")
tooSoon:
  blocked=.true; signal off syntax
call assertTrue blocked,"undisputed amount cannot finalize until dispute window has expired"
f=ops~finalizeCloseout("FINAL-WIN",co~closeoutId,"2026-10-13","VMM-LEGAL")
call assertEq "ORIGINAL_UNDISPUTED",f~basis,"undisputed finalization adopts original determination"
call assertNear -750000,f~netAmountToVMM,0.01,"undisputed amount preserved exactly"
settle=d~settleCloseout("SETTLE-WIN",co~closeoutId,"2026-10-14","BANK-PAYMENT-WIN","VMM-TREASURY")
call assertNear 750000,settle~amount,0.01,"settlement follows final undisputed amount"
call assertEq "VECTOR_MERIDIAN_MARKETS_LTD",settle~payerEntity,"VMM pays negative final amount"
say "PASS test_closeout_undisputed_finalization_window"
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
