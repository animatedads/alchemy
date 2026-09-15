v=.VectorMeridianMarkets~new
x=.VMMInstitutionalSyntheticService~new(v)
c=.VMMInstitutionalCounterparty~new("AJI","ALL_JAPAN_INSURANCE","REL-AJI","JP","KYC-AJI","ISDA-AJI","CSA-AJI","VMM-ONBOARD")
x~registerCounterparty(c)
x~setRiskPolicy(.VMMSyntheticRiskPolicy~new("SYN-RISK-JPY","JPY",100000000000,50000000000,100,"POL-SYN-JPY"),"VMM-RISK")
p=.VMMPortfolioReferencePosition~new("P-JGB","AJI","JGB","JAPAN_GOVERNMENT","SOVEREIGN_BOND","JPY",10000000000,"ALL_JAPAN_INSURANCE","","AJI-CURRENT","","VAL-JGB")
s=.VMMPortfolioSnapshot~new("AJI-SNAP-PREM","AJI","ALL_JAPAN_INSURANCE","JPY","20260828T132000",.array~of(p),"AJI-POSITIONS","","VMM-PORTFOLIO-CONTROL")
x~registerPortfolioSnapshot(s)
x~createOffer("OFF-PREM","REQ-PREM","AJI","AJI-SNAP-PREM","JPY",10000000000,5,25,120000000,"20260901","20310831","20260828T140000","20260828T132100","MODEL-PREM","MKT-PREM","RISK-PREM")
k=x~acceptOffer("CON-PREM","OFF-PREM","20260828T132200","ALL_JAPAN_INSURANCE","AJI-SIGNER")
p1=.VMMSyntheticPremiumPeriod~new("PREM-1","JPY","20260901","20260930","20261005",60000000,"SCHED-PREM-1")
p2=.VMMSyntheticPremiumPeriod~new("PREM-2","JPY","20261001","20261031","20261105",60000000,"SCHED-PREM-2")
x~setPremiumSchedule("CON-PREM",.array~of(p1,p2),"VMM-OTC-OPS")
a1=x~recordPremiumAccrual("ACCR-1","CON-PREM","PREM-1",15,30,"20260915","ACCR-EVID-1","VMM-FINANCE")
call assertNear 30000000,a1~cumulativeAccruedAmount,0.01,"half-period premium accrual"
a2=x~recordPremiumAccrual("ACCR-2","CON-PREM","PREM-1",30,30,"20260930","ACCR-EVID-2","VMM-FINANCE")
call assertNear 60000000,x~premiumAccrued("CON-PREM"),0.01,"full first-period accrued premium"
t1=.VMMSyntheticPremiumSettlement~new("SET-PREM-1","CON-PREM","PREM-1","JPY",40000000,"ALL_JAPAN_INSURANCE","VECTOR_MERIDIAN_MARKETS_LTD","BANK-PAYMENT-EVID-1","20261005T090000","VMM-CASH-CONTROL")
x~recordPremiumSettlement(t1)
call assertNear 20000000,x~premiumReceivable("CON-PREM"),0.01,"part-paid accrued premium receivable"
t2=.VMMSyntheticPremiumSettlement~new("SET-PREM-2","CON-PREM","PREM-1","JPY",20000000,"ALL_JAPAN_INSURANCE","VECTOR_MERIDIAN_MARKETS_LTD","BANK-PAYMENT-EVID-2","20261005T100000","VMM-CASH-CONTROL")
x~recordPremiumSettlement(t2)
call assertNear 60000000,x~premiumSettled("CON-PREM"),0.01,"first premium period fully settled"
call assertNear 0,x~premiumReceivable("CON-PREM"),0.01,"no accrued premium receivable remains"
/* Federation cannot be named as premium payee. */
blocked=.false
signal on syntax name badPayee
bad=.VMMSyntheticPremiumSettlement~new("SET-BAD","CON-PREM","PREM-2","JPY",1,"ALL_JAPAN_INSURANCE","FEDERATIONBANK_CORE","BANK-EVID-BAD","20261105","VMM-CASH-CONTROL")
signal off syntax
raise syntax 88.900 array("ASSERT_FEDERATION_PREMIUM_PAYEE_ALLOWED")
badPayee:
  blocked=.true; signal off syntax
if \blocked then raise syntax 88.900 array("ASSERT_BAD_PAYEE_REJECTION")
say "PASS test_synthetic_premium_accrual_settlement"
exit 0
::routine assertNear
  use strict arg expected,actual,tolerance,label
  if abs(expected-actual)>tolerance then raise syntax 88.900 array("ASSERT_NEAR",label,"expected",expected,"actual",actual)
::requires "VMMSyntheticProducts.cls"
