v=.VectorMeridianMarkets~new
x=.VMMInstitutionalSyntheticService~new(v)
c=.VMMInstitutionalCounterparty~new("AJI","ALL_JAPAN_INSURANCE","REL-AJI","JP","KYC-AJI","ISDA-AJI","CSA-AJI","VMM-ONBOARD")
x~registerCounterparty(c)
x~setRiskPolicy(.VMMSyntheticRiskPolicy~new("SYN-RISK-JPY","JPY",100000000000,50000000000,100,"POL-SYN-JPY"),"VMM-RISK")
p=.VMMPortfolioReferencePosition~new("P-JGB","AJI","JGB","JAPAN_GOVERNMENT","SOVEREIGN_BOND","JPY",10000000000,"ALL_JAPAN_INSURANCE","","AJI-CURRENT","","VAL-JGB")
s=.VMMPortfolioSnapshot~new("AJI-SNAP-ACC","AJI","ALL_JAPAN_INSURANCE","JPY","20260828T132000",.array~of(p),"AJI-POSITIONS","","VMM-PORTFOLIO-CONTROL")
x~registerPortfolioSnapshot(s)
x~createOffer("OFF-ACC","REQ-ACC","AJI","AJI-SNAP-ACC","JPY",10000000000,5,25,120000000,"20260901","20310831","20260828T140000","20260828T132100","MODEL-PREM","MKT-PREM","RISK-PREM")
x~acceptOffer("CON-ACC","OFF-ACC","20260828T132200","ALL_JAPAN_INSURANCE","AJI-SIGNER")
p1=.VMMSyntheticPremiumPeriod~new("PREM-1","JPY","20260901","20260930","20261005",120000000,"SCHED-PREM-1")
x~setPremiumSchedule("CON-ACC",.array~of(p1),"VMM-OTC-OPS")
a1=x~recordPremiumAccrual("ACCR-A","CON-ACC","PREM-1",15,30,"20260915","ACCR-EVID-A","VMM-FINANCE")
a2=x~recordPremiumAccrual("ACCR-B","CON-ACC","PREM-1",30,30,"20260930","ACCR-EVID-B","VMM-FINANCE")
eng=.AccountingEngine~new("VECTOR_MERIDIAN_MARKETS_LTD","VMM-STAT","ENTITY_GAAP")
.VMMAccountingPolicy~configureEngine(eng,.AccountingPeriod~new("2026-09","2026-09-01","2026-09-30"))
acct=.VMMAccountingService~new(v,eng)
r1=acct~postPremiumAccrual(a1,"2026-09-15","2026-09")
/* Restart the adapter between cumulative accruals: delta must derive from posted accounting truth, not local adapter memory. */
acct=.VMMAccountingService~new(v,eng)
r2=acct~postPremiumAccrual(a2,"2026-09-30","2026-09")
call assertTrue r1~ok,"first accrual posted"
call assertTrue r2~ok,"incremental accrual posted"
call assertEq 12000000000,acct~book~balance("1200","JPY")~netDebitMinor,"full premium receivable in minor units"
call assertEq -12000000000,acct~book~balance("4100","JPY")~netDebitMinor,"premium revenue credit"
settle=.VMMSyntheticPremiumSettlement~new("SET-ACC","CON-ACC","PREM-1","JPY",120000000,"ALL_JAPAN_INSURANCE","VECTOR_MERIDIAN_MARKETS_LTD","PAYMENT-EVID","20261005T090000","VMM-CASH")
x~recordPremiumSettlement(settle)
/* Add October without altering September postings. */
acct~book~addPeriod(.AccountingPeriod~new("2026-10","2026-10-01","2026-10-31"))
rs=acct~postPremiumSettlement(settle,"2026-10-05","2026-10")
call assertTrue rs~ok,"premium settlement posted"
call assertEq 12000000000,acct~book~balance("1000","JPY")~netDebitMinor,"cash received"
call assertEq 0,acct~book~balance("1200","JPY")~netDebitMinor,"premium receivable cleared"
call assertEq 120000000,x~premiumSettled("CON-ACC"),"operational settlement remains source truth"
say "PASS test_accounting_premium_accrual_settlement"
exit 0
::routine assertTrue
  use strict arg value,label
  if \value then raise syntax 88.900 array("ASSERT_TRUE",label)
::routine assertEq
  use strict arg expected,actual,label
  if expected<>actual then raise syntax 88.900 array("ASSERT_EQ",label,"expected",expected,"actual",actual)
::requires "VMMAccounting.cls"
