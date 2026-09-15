v=.VectorMeridianMarkets~new
x=.VMMInstitutionalSyntheticService~new(v)
c=.VMMInstitutionalCounterparty~new("AJI","ALL_JAPAN_INSURANCE","REL-AJI","JP","KYC-AJI","ISDA-AJI","CSA-AJI","VMM-ONBOARD")
x~registerCounterparty(c)
x~setRiskPolicy(.VMMSyntheticRiskPolicy~new("SYN-RISK-JPY","JPY",100000000000,50000000000,100,"POL-SYN-JPY"),"VMM-RISK")
x~setLifecyclePolicy(.VMMSyntheticLifecyclePolicy~new("LIFE-JPY","JPY",5,10,85,"POL-LIFE-JPY"),"VMM-RISK")
p=.VMMPortfolioReferencePosition~new("P-JGB","AJI","JGB","JAPAN_GOVERNMENT","SOVEREIGN_BOND","JPY",10000000000,"ALL_JAPAN_INSURANCE","","AJI-CURRENT","","VAL-JGB")
s=.VMMPortfolioSnapshot~new("AJI-SNAP-XVA","AJI","ALL_JAPAN_INSURANCE","JPY","20260828T132000",.array~of(p),"AJI-POSITIONS","","VMM-PORTFOLIO-CONTROL")
x~registerPortfolioSnapshot(s)
x~createOffer("OFF-XVA","REQ-XVA","AJI","AJI-SNAP-XVA","JPY",10000000000,5,25,120000000,"20260901","20310831","20260828T140000","20260828T132100","MODEL-XVA","MKT-XVA","RISK-XVA")
x~acceptOffer("CON-XVA","OFF-XVA","20260828T132200","ALL_JAPAN_INSURANCE","AJI-SIGNER")
v1=x~valueContract("VAL-XVA-1","CON-XVA",9000000000,"20260930","MKT-SEP","MODEL-SEP","VMM-VALUATION")
v2=x~valueContract("VAL-XVA-2","CON-XVA",8500000000,"20261031","MKT-OCT","MODEL-OCT","VMM-VALUATION")
contractual=v2~vmmLiabilityMtm
r=.VMMSyntheticXVAReport~new("XVA-1","CON-XVA","VAL-XVA-2","JPY",100000000,50000000,"20261031T170000","CREDIT-CURVE-AJI","VMM-FUNDING-CURVE","XVA-MODEL-1","VMM-XVA")
x~recordXVA(r)
call assertNear 150000000,r~totalXva,0.01,"CVA and FVA retained separately but summed for risk view"
call assertNear contractual,v2~vmmLiabilityMtm,0.01,"XVA cannot rewrite contractual liability"
change=v2~vmmLiabilityMtm-v1~vmmLiabilityMtm
he=x~assessHedgeEffectiveness("HE-1","CON-XVA","VAL-XVA-1","VAL-XVA-2",change*0.90,"20261031T171000","HEDGE-METHOD-1","HEDGE-MARKS-1","VMM-MARKET-RISK")
call assertNear 90,he~offsetPct,0.000001,"90 percent hedge offset"
call assertEq "EFFECTIVE",he~status,"90 percent exceeds independent effectiveness threshold"
he2=x~assessHedgeEffectiveness("HE-2","CON-XVA","VAL-XVA-1","VAL-XVA-2",change*0.40,"20261031T172000","HEDGE-METHOD-1","HEDGE-MARKS-2","VMM-MARKET-RISK")
call assertEq "INEFFECTIVE",he2~status,"bad hedge is recorded as bad news"
call assertNear change*0.60,he2~residualAmount,0.01,"ineffective hedge residual remains visible"
say "PASS test_synthetic_xva_hedge_effectiveness"
exit 0
::routine assertEq
  use strict arg expected,actual,label
  if expected<>actual then raise syntax 88.900 array("ASSERT_EQ",label,"expected",expected,"actual",actual)
::routine assertNear
  use strict arg expected,actual,tolerance,label
  if abs(expected-actual)>tolerance then raise syntax 88.900 array("ASSERT_NEAR",label,"expected",expected,"actual",actual)
::requires "VMMSyntheticProducts.cls"
