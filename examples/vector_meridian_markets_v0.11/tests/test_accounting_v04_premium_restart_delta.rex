numeric digits 50
storePath="./tests/tmp_vmm_accounting_premium_restart_v010.jsonl"
v=.VectorMeridianMarkets~new
x=.VMMInstitutionalSyntheticService~new(v)
c=.VMMInstitutionalCounterparty~new("AJI","ALL_JAPAN_INSURANCE","REL-AJI","JP","KYC-AJI","ISDA-AJI","CSA-AJI","VMM-ONBOARD")
x~registerCounterparty(c)
x~setRiskPolicy(.VMMSyntheticRiskPolicy~new("SYN-RISK-JPY","JPY",100000000000,50000000000,100,"POL-SYN-JPY"),"VMM-RISK")
p=.VMMPortfolioReferencePosition~new("P-JGB","AJI","JGB","JAPAN_GOVERNMENT","SOVEREIGN_BOND","JPY",10000000000,"ALL_JAPAN_INSURANCE","","AJI-CURRENT","","VAL-JGB")
s=.VMMPortfolioSnapshot~new("AJI-SNAP-DUR","AJI","ALL_JAPAN_INSURANCE","JPY","20260828T132000",.array~of(p),"AJI-POSITIONS","","VMM-PORTFOLIO-CONTROL")
x~registerPortfolioSnapshot(s)
x~createOffer("OFF-DUR","REQ-DUR","AJI","AJI-SNAP-DUR","JPY",10000000000,5,25,120000000,"20260901","20310831","20260828T140000","20260828T132100","MODEL-PREM","MKT-PREM","RISK-PREM")
x~acceptOffer("CON-DUR","OFF-DUR","20260828T132200","ALL_JAPAN_INSURANCE","AJI-SIGNER")
p1=.VMMSyntheticPremiumPeriod~new("PREM-DUR","JPY","20260901","20260930","20261005",120000000,"SCHED-PREM-DUR")
x~setPremiumSchedule("CON-DUR",.array~of(p1),"VMM-OTC-OPS")
a1=x~recordPremiumAccrual("ACCR-DUR-A","CON-DUR","PREM-DUR",15,30,"20260915","ACCR-EVID-A","VMM-FINANCE")
a2=x~recordPremiumAccrual("ACCR-DUR-B","CON-DUR","PREM-DUR",30,30,"20260930","ACCR-EVID-B","VMM-FINANCE")
eng=.VMMAccountingStore~createEngine(storePath,.AccountingPeriod~new("2026-09","2026-09-01","2026-09-30"))
acct=.VMMAccountingService~new(v,eng)
r1=acct~postPremiumAccrual(a1,"2026-09-15","2026-09")
call assertEq "POSTED",r1~status,"first half premium accrual posts"
call assertEq 6000000000,acct~book~balance("1200","JPY")~netDebitMinor,"first half exact JPY minor units"

/* Recover the accounting book from JSONL before the cumulative second accrual. */
eng2=.VMMAccountingStore~recoverEngine(storePath)
acct2=.VMMAccountingService~new(v,eng2)
r2=acct2~postPremiumAccrual(a2,"2026-09-30","2026-09")
call assertEq "POSTED",r2~status,"second cumulative premium accrual posts after process restart"
call assertEq 12000000000,acct2~book~balance("1200","JPY")~netDebitMinor,"incremental delta derives from recovered posted truth"
call assertEq -12000000000,acct2~book~balance("4100","JPY")~netDebitMinor,"premium revenue survives and advances after restart"
call assertEq "vmm.accounting/0.11",.VMMAccountingBuild~protocol,"v0.11 accounting protocol"
call assertEq "vmm-accounting-artifact/0.11:premium-accrual",r2~policyIdentity,"v0.11 executable policy identity persisted"
say "PASS test_accounting_v04_premium_restart_delta"
exit 0

::routine assertEq
  use strict arg expected,actual,label
  if expected<>actual then raise syntax 88.900 array("ASSERT_EQ",label,"expected",expected,"actual",actual)

::requires "VMMAccountingPersistence.cls"
