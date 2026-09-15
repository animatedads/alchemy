v=.VectorMeridianMarkets~new
x=.VMMInstitutionalSyntheticService~new(v)
cp=.VMMInstitutionalCounterparty~new("AJI","ALL_JAPAN_INSURANCE","REL-AJI","JP","KYC-AJI","ISDA-AJI","CSA-AJI","VMM-ONBOARD")
x~registerCounterparty(cp)
x~setRiskPolicy(.VMMSyntheticRiskPolicy~new("RISK-JPY","JPY",100000000000,50000000000,100,"RISK-POL"),"VMM-RISK")
p=.VMMPortfolioReferencePosition~new("P-AF","AJI","JGB-AF","JAPAN_GOVERNMENT","SOVEREIGN_BOND","JPY",10000000,"ALL_JAPAN_INSURANCE","","BOOK-AF","","VAL-AF")
s=.VMMPortfolioSnapshot~new("SNAP-AF","AJI","ALL_JAPAN_INSURANCE","JPY","20260828",.array~of(p),"POS-AF","","VMM-PORTFOLIO")
x~registerPortfolioSnapshot(s)
x~createOffer("OFF-AF","REQ-AF","AJI","SNAP-AF","JPY",10000000,5,25,100000,"20260901","20310831","20260828T140000","20260828T132100","MODEL-AF","MKT-AF","RISK-AF")
k=x~acceptOffer("CON-AF","OFF-AF","20260828T132200","ALL_JAPAN_INSURANCE","AJI-SIGNER")
d=.VMMInstitutionalDefaultCloseoutService~new(x)
d~setPolicy(.VMMSyntheticDefaultPolicy~new("DEF-JPY","JPY",2,1,3,"ISDA-CLOSEOUT","DEF-POL"),"VMM-LEGAL")
ops=.VMMCloseoutOperationsService~new(d)
ops~setPolicy(.VMMCloseoutOperationsPolicy~new("OPS-JPY","JPY",2,3,"INDEPENDENT-VALUATION-AGENT","LEGAL-NETTING-OPINION-POLICY","OPS-POL"),"VMM-LEGAL")
ev=d~declareDefault("DEF-AF",k~contractId,"INSOLVENCY","ALL_JAPAN_INSURANCE","2026-10-06","2026-10-06","INSOLVENCY-AF","VMM-LEGAL")
d~assessUncured("UNCURED-AF",ev~eventId,"2026-10-07","UNCURED-AF","VMM-LEGAL")
t=d~electTermination("TERM-AF",ev~eventId,"VECTOR_MERIDIAN_MARKETS_LTD","2026-10-07","TERM-AF","ORIGINAL-VALUATION-AGENT","VMM-LEGAL")
co=d~determineCloseout("CLOSE-AF",t~terminationId,2000000,"2026-10-10","ISDA-METHOD-ORIG","MKT-ORIG","CSA-NET-AF","VMM-VALUATION")
disp=ops~disputeCloseout("DISP-AF",co~closeoutId,"ALL_JAPAN_INSURANCE",1400000,"2026-10-11","AJI-DISPUTE-AF","AJI-LEGAL")
res=ops~resolveDispute("RES-AF",disp~disputeId,1600000,"2026-10-12","INDEPENDENT-VALUATION-AGENT","ISDA-METHOD-FALLBACK","MKT-FALLBACK","VMM-LEGAL")
f=ops~finalizeCloseout("FINAL-AF",co~closeoutId,"2026-10-12","VMM-LEGAL")

eng=.AccountingEngine~new("VECTOR_MERIDIAN_MARKETS_LTD","VMM-STAT","ENTITY_GAAP")
.VMMAccountingPolicy~configureEngine(eng,.AccountingPeriod~new("2026-10","2026-10-01","2026-10-31"))
acct=.VMMAccountingService~new(v,eng)
r=acct~postCloseoutFinalization(f,"2026-10-12","2026-10")
call assertTrue r~ok,"v0.9 finalized close-out posts through AccountingEvent path"
call assertEq "VMM_SYNTHETIC_CLOSEOUT_FINALIZED",r~entry~eventType,"accounting event is finalization, not original disputed determination"
call assertEq "vmm-accounting-artifact/0.11:closeout-finalized",r~entry~policyIdentity,"journal freezes v0.9 finalization policy identity"
call assertEq 160000000,acct~book~balance("1500","JPY")~netDebitMinor,"final receivable uses fallback valuation amount only"
call assertEq -160000000,acct~book~balance("4300","JPY")~netDebitMinor,"final legal recovery recognized at resolved amount"
call assertNear 2000000,co~grossAmountToVMM,0.01,"operational original determination remains immutable after accounting"
settle=d~settleCloseout("SETTLE-AF",co~closeoutId,"2026-10-13","BANK-PAYMENT-AF","VMM-TREASURY")
rs=acct~postCloseoutFinalSettlement(settle,f,"2026-10-13","2026-10")
call assertTrue rs~ok,"cash settlement consumes finalized close-out receivable"
call assertEq 0,acct~book~balance("1500","JPY")~netDebitMinor,"final receivable cleared by settlement"
call assertEq 160000000,acct~book~balance("1000","JPY")~netDebitMinor,"cash records resolved amount, not disputed original"
replay=acct~postCloseoutFinalization(f,"2026-10-12","2026-10")
call assertEq "DUPLICATE",replay~status,"finalization event replay returns immutable original entry"
say "PASS test_accounting_closeout_finalization_dispute"
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
::requires "VMMAccounting.cls"
