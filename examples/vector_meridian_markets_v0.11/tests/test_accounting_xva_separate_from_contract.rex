v=.VectorMeridianMarkets~new
x=.VMMInstitutionalSyntheticService~new(v)
c=.VMMInstitutionalCounterparty~new("AJI","ALL_JAPAN_INSURANCE","REL-AJI","JP","KYC-AJI","ISDA-AJI","CSA-AJI","VMM-ONBOARD")
x~registerCounterparty(c)
x~setRiskPolicy(.VMMSyntheticRiskPolicy~new("SYN-RISK-JPY","JPY",100000000000,50000000000,100,"POL-SYN-JPY"),"VMM-RISK")
x~setLifecyclePolicy(.VMMSyntheticLifecyclePolicy~new("LC-JPY","JPY",10,10,80,"POL-LC-JPY"),"VMM-RISK")
p=.VMMPortfolioReferencePosition~new("P-JGB","AJI","JGB","JAPAN_GOVERNMENT","SOVEREIGN_BOND","JPY",10000000000,"ALL_JAPAN_INSURANCE","","AJI-CURRENT","","VAL-JGB")
s=.VMMPortfolioSnapshot~new("AJI-SNAP-XVA","AJI","ALL_JAPAN_INSURANCE","JPY","20260828T132000",.array~of(p),"AJI-POSITIONS","","VMM-PORTFOLIO-CONTROL")
x~registerPortfolioSnapshot(s)
x~createOffer("OFF-XVA","REQ-XVA","AJI","AJI-SNAP-XVA","JPY",10000000000,5,25,120000000,"20260901","20310831","20260828T140000","20260828T132100","MODEL","MKT","RISK")
k=x~acceptOffer("CON-XVA","OFF-XVA","20260828T132200","ALL_JAPAN_INSURANCE","AJI-SIGNER")
val=x~valueContract("VAL-XVA","CON-XVA",9000000000,"20260828T150000","MKT-VAL","MODEL-VAL","VMM-VAL")
contractualBefore=val~vmmLiabilityMtm
rep=.VMMSyntheticXVAReport~new("XVA-1","CON-XVA","VAL-XVA","JPY",5000000,3000000,"20260828T151000","CREDIT-EVID","FUNDING-CURVE","XVA-MODEL","VMM-XVA")
x~recordXVA(rep)
eng=.AccountingEngine~new("VECTOR_MERIDIAN_MARKETS_LTD","VMM-STAT","ENTITY_GAAP")
.VMMAccountingPolicy~configureEngine(eng,.AccountingPeriod~new("2026-08","2026-08-01","2026-08-31"))
acct=.VMMAccountingService~new(v,eng)
r=acct~postXVA(rep,"2026-08-28","2026-08")
call assertTrue r~ok,"XVA accounting adjustment posted"
call assertEq 800000000,acct~book~balance("6300","JPY")~netDebitMinor,"XVA expense"
call assertEq -800000000,acct~book~balance("2300","JPY")~netDebitMinor,"XVA reserve credit"
call assertEq contractualBefore,x~valuation("VAL-XVA")~vmmLiabilityMtm,"accounting XVA cannot rewrite contractual valuation"
say "PASS test_accounting_xva_separate_from_contract"
exit 0
::routine assertTrue
  use strict arg value,label
  if \value then raise syntax 88.900 array("ASSERT_TRUE",label)
::routine assertEq
  use strict arg expected,actual,label
  if expected<>actual then raise syntax 88.900 array("ASSERT_EQ",label,"expected",expected,"actual",actual)
::requires "VMMAccounting.cls"
