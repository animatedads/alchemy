v=.VectorMeridianMarkets~new
x=.VMMInstitutionalSyntheticService~new(v)
c=.VMMInstitutionalCounterparty~new("AJI","ALL_JAPAN_INSURANCE","REL-AJI","JP","KYC-AJI","ISDA-AJI","CSA-AJI","VMM-ONBOARD")
x~registerCounterparty(c)
x~setRiskPolicy(.VMMSyntheticRiskPolicy~new("SYN-RISK-JPY","JPY",100000000000,50000000000,100,"POL-SYN-JPY"),"VMM-RISK")
p=.VMMPortfolioReferencePosition~new("P-JGB","AJI","JGB","JAPAN_GOVERNMENT","SOVEREIGN_BOND","JPY",10000000000,"ALL_JAPAN_INSURANCE","","AJI-CURRENT","","VAL-JGB")
s=.VMMPortfolioSnapshot~new("AJI-SNAP-IM","AJI","ALL_JAPAN_INSURANCE","JPY","20260828T132000",.array~of(p),"AJI-POSITIONS","","VMM-PORTFOLIO-CONTROL")
x~registerPortfolioSnapshot(s)
x~createOffer("OFF-IM","REQ-IM","AJI","AJI-SNAP-IM","JPY",10000000000,5,25,120000000,"20260901","20310831","20260828T140000","20260828T132100","MODEL-IM","MKT-IM","RISK-IM")
x~acceptOffer("CON-IM","OFF-IM","20260828T132200","ALL_JAPAN_INSURANCE","AJI-SIGNER")
t=.VMMSyntheticInitialMarginTerms~new("IM-TERMS","JPY",1000000000,"SOVEREIGN_BOND",1000,"CSA-IM-POLICY")
x~setInitialMarginTerms("CON-IM",t,"VMM-COLLATERAL")
a=.VMMSyntheticInitialMarginTransfer~new("IM-XFER-1","CON-IM","JPY","JGB-COLL-1","SOVEREIGN_BOND",1000000000,500,"VECTOR_MERIDIAN_MARKETS_LTD","ALL_JAPAN_INSURANCE","THIRD_PARTY_CUSTODIAN","CONTROL-RECEIPT-IM-1","20260901T090000","VMM-COLLATERAL")
x~recordInitialMarginTransfer(a)
call assertNear 950000000,a~recognizedValue,0.01,"5 percent haircut recognized value"
call assertNear 50000000,x~initialMarginShortfall("CON-IM"),0.01,"initial margin shortfall after haircut"
b=.VMMSyntheticInitialMarginTransfer~new("IM-XFER-2","CON-IM","JPY","JGB-COLL-2","SOVEREIGN_BOND",60000000,500,"VECTOR_MERIDIAN_MARKETS_LTD","ALL_JAPAN_INSURANCE","THIRD_PARTY_CUSTODIAN","CONTROL-RECEIPT-IM-2","20260901T091000","VMM-COLLATERAL")
x~recordInitialMarginTransfer(b)
call assertNear 0,x~initialMarginShortfall("CON-IM"),0.01,"recognized collateral satisfies initial margin"
blocked=.false
signal on syntax name badHaircut
bad=.VMMSyntheticInitialMarginTransfer~new("IM-XFER-BAD","CON-IM","JPY","JGB-COLL-BAD","SOVEREIGN_BOND",100000000,1500,"VECTOR_MERIDIAN_MARKETS_LTD","ALL_JAPAN_INSURANCE","THIRD_PARTY_CUSTODIAN","CONTROL-BAD","20260901T092000","VMM-COLLATERAL")
x~recordInitialMarginTransfer(bad)
signal off syntax
raise syntax 88.900 array("ASSERT_EXCESS_HAIRCUT_ACCEPTED")
badHaircut:
  blocked=.true; signal off syntax
if \blocked then raise syntax 88.900 array("ASSERT_HAIRCUT_REJECTION")
say "PASS test_synthetic_initial_margin_haircut"
exit 0
::routine assertNear
  use strict arg expected,actual,tolerance,label
  if abs(expected-actual)>tolerance then raise syntax 88.900 array("ASSERT_NEAR",label,"expected",expected,"actual",actual)
::requires "VMMSyntheticProducts.cls"
