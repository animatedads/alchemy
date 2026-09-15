v=.VectorMeridianMarkets~new
x=.VMMInstitutionalSyntheticService~new(v)
c=.VMMInstitutionalCounterparty~new("AJI","ALL_JAPAN_INSURANCE","REL-AJI","JP","KYC-AJI","ISDA-AJI","CSA-AJI","VMM-ONBOARD")
x~registerCounterparty(c)
x~setRiskPolicy(.VMMSyntheticRiskPolicy~new("SYN-RISK-JPY","JPY",100000000000,50000000000,100,"POL-SYN-JPY"),"VMM-RISK")
p=.VMMPortfolioReferencePosition~new("P-ACC-CO","AJI","JGB-ACC-CO","JAPAN_GOVERNMENT","SOVEREIGN_BOND","JPY",10000000,"ALL_JAPAN_INSURANCE","","BOOK-ACC-CO","","VAL-ACC-CO")
s=.VMMPortfolioSnapshot~new("SNAP-ACC-CO","AJI","ALL_JAPAN_INSURANCE","JPY","20260828",.array~of(p),"AJI-POSITIONS-ACC-CO","","VMM-PORTFOLIO")
x~registerPortfolioSnapshot(s)
x~createOffer("OFF-ACC-CO","REQ-ACC-CO","AJI","SNAP-ACC-CO","JPY",10000000,5,25,120000,"20260901","20310831","20260828T140000","20260828T132100","MODEL-ACC-CO","MKT-ACC-CO","RISK-ACC-CO")
k=x~acceptOffer("CON-ACC-CO","OFF-ACC-CO","20260828T132200","ALL_JAPAN_INSURANCE","AJI-SIGNER")
/* Establish operational cash VM and post the same event into VMM accounting first. */
x~setCollateralTerms(k~contractId,.VMMSyntheticCollateralTerms~new("CSA-ACC-CO","JPY",0,0,0,"COLLATERAL-POLICY-ACC-CO"),"VMM-COLLATERAL")
val=x~valueContract("VAL-ACC-CO",k~contractId,9400000,"20260828T150000","MKT-VAL-ACC-CO","MODEL-VAL-ACC-CO","VMM-VALUATION")
mc=x~issueVariationMarginCall("CALL-ACC-CO",k~contractId,val~valuationId,"20260828T151000","VMM-COLLATERAL")
vm=.VMMSyntheticCollateralTransfer~new("VM-ACC-CO",k~contractId,mc~callId,"JPY",500000,"VMM_TO_COUNTERPARTY","CUSTODIAN-ACC-CO","CONTROL-VM-ACC-CO","20260828T152000","VMM-COLLATERAL")
x~recordCollateralTransfer(vm)
eng=.AccountingEngine~new("VECTOR_MERIDIAN_MARKETS_LTD","VMM-STAT","ENTITY_GAAP")
.VMMAccountingPolicy~configureEngine(eng,.AccountingPeriod~new("2026-08","2026-08-01","2026-08-31"))
eng~book~addPeriod(.AccountingPeriod~new("2026-10","2026-10-01","2026-10-31"))
acct=.VMMAccountingService~new(v,eng)
rvm=acct~postVariationMarginTransfer(vm,"2026-08-28","2026-08")
call assertTrue rvm~ok,"variation margin reaches Accounting Core transaction path"
call assertEq 50000000,acct~book~balance("1400","JPY")~netDebitMinor,"cash VM carrying value posted before close-out"
/* Create payment default and legal close-out. */
pp=.VMMSyntheticPremiumPeriod~new("PREM-ACC-CO","JPY","20260901","20260930","20261005",120000,"SCHED-ACC-CO")
x~setPremiumSchedule(k~contractId,.array~of(pp),"VMM-OTC-OPS")
x~recordPremiumAccrual("ACCR-ACC-CO",k~contractId,pp~periodId,30,30,"20260930","ACCR-EVID-ACC-CO","VMM-FINANCE")
d=.VMMInstitutionalDefaultCloseoutService~new(x)
d~setPolicy(.VMMSyntheticDefaultPolicy~new("DEF-POL-ACC-CO","JPY",2,1,3,"ISDA-2002-CLOSEOUT-AMOUNT","POL-DEFAULT-ACC-CO"),"VMM-LEGAL")
ev=d~declareDefault("DEF-ACC-CO",k~contractId,"FAILURE_TO_PAY_PREMIUM","ALL_JAPAN_INSURANCE","2026-10-06","2026-10-06","UNPAID-PREMIUM-ACC-CO","VMM-LEGAL")
d~assessUncured("UNCURED-ACC-CO",ev~eventId,"2026-10-09","CURE-EXPIRED-ACC-CO","VMM-LEGAL")
t=d~electTermination("TERM-ACC-CO",ev~eventId,"VECTOR_MERIDIAN_MARKETS_LTD","2026-10-09","TERM-NOTICE-ACC-CO","VALUATION-AGENT-ACC-CO","VMM-LEGAL")
co=d~determineCloseout("CLOSE-ACC-CO",t~terminationId,-1500000,"2026-10-10","ISDA-CLOSEOUT-METHOD-ACC","MKT-CLOSEOUT-ACC","CSA-NETTING-ACC","VMM-VALUATION-CONTROL")
rc=acct~postCloseoutDetermination(co,"2026-10-10","2026-10")
call assertTrue rc~ok,"close-out determination posted through AccountingEvent policy dispatch"
call assertEq "VMM_SYNTHETIC_CLOSEOUT_DETERMINED",rc~entry~eventType,"journal retains exact operational event type"
call assertEq "vmm-accounting-artifact/0.11:closeout-determined",rc~entry~policyIdentity,"journal freezes exact VMM accounting policy identity"
call assertTrue rc~entry~sourceEventFingerprint<>"","journal freezes source event fingerprint"
call assertEq "ALL_JAPAN_INSURANCE",rc~entry~counterpartyEntityId,"counterparty is evidence dimension, not book owner"
call assertEq 0,acct~book~balance("1400","JPY")~netDebitMinor,"cash VM carrying value cleared by close-out netting"
call assertEq 150000000,acct~book~balance("6400","JPY")~netDebitMinor,"gross contractual close-out loss recognized separately"
call assertEq -100000000,acct~book~balance("2400","JPY")~netDebitMinor,"net close-out payable recognized"
/* Exact operational replay must be a duplicate, not a second posting or a new policy decision. */
replay=acct~postCloseoutDetermination(co,"2026-10-10","2026-10")
call assertTrue replay~ok,"exact close-out event replay accepted idempotently"
call assertEq "DUPLICATE",replay~status,"Accounting Core replay resolved before policy dispatch"
call assertEq rc~entry~entryId,replay~entry~entryId,"duplicate returns the immutable original entry"
settle=d~settleCloseout("SETTLE-ACC-CO",co~closeoutId,"2026-10-11","BANK-CLOSEOUT-PAYMENT-ACC","VMM-TREASURY")
rs=acct~postCloseoutSettlement(settle,co,"2026-10-11","2026-10")
call assertTrue rs~ok,"close-out settlement posted through AccountingEvent policy dispatch"
call assertEq 0,acct~book~balance("2400","JPY")~netDebitMinor,"settlement clears close-out payable"
call assertEq -150000000,acct~book~balance("1000","JPY")~netDebitMinor,"cash reflects VM delivery plus net close-out payment"
say "PASS test_accounting_closeout_event_path"
exit 0
::routine assertEq
  use strict arg expected,actual,label
  if expected<>actual then raise syntax 88.900 array("ASSERT_EQ",label,"expected",expected,"actual",actual)
::routine assertTrue
  use strict arg value,label
  if \value then raise syntax 88.900 array("ASSERT_TRUE",label)
::requires "VMMAccounting.cls"
