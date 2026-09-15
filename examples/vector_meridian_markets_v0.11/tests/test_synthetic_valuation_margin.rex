v=.VectorMeridianMarkets~new
x=.VMMInstitutionalSyntheticService~new(v)
c=.VMMInstitutionalCounterparty~new("AJI","ALL_JAPAN_INSURANCE","REL-AJI","JP","KYC-AJI","ISDA-AJI","CSA-AJI","VMM-ONBOARD")
x~registerCounterparty(c)
x~setRiskPolicy(.VMMSyntheticRiskPolicy~new("SYN-RISK-JPY","JPY",100000000000,50000000000,100,"POL-SYN-JPY"),"VMM-RISK")
p=.VMMPortfolioReferencePosition~new("P-JGB","AJI","JGB-BASKET","JAPAN_GOVERNMENT","SOVEREIGN_BOND","JPY",10000000000,"ALL_JAPAN_INSURANCE","","AJI-CURRENT","","VAL-JGB")
s=.VMMPortfolioSnapshot~new("AJI-SNAP-V","AJI","ALL_JAPAN_INSURANCE","JPY","20260828T132000",.array~of(p),"AJI-POSITIONS","","VMM-PORTFOLIO-CONTROL")
x~registerPortfolioSnapshot(s)
o=x~createOffer("OFF-V","REQ-V","AJI","AJI-SNAP-V","JPY",10000000000,5,25,120000000,"20260901","20310831","20260828T140000","20260828T132100","MODEL-OFFER","MKT-OFFER","RISK-OFFER")
k=x~acceptOffer("CON-V","OFF-V","20260828T132200","ALL_JAPAN_INSURANCE","AJI-SIGNER")
x~setCollateralTerms("CON-V",.VMMSyntheticCollateralTerms~new("CSA-TERMS-V","JPY",500000000,50000000,100000000,"CSA-POLICY-V"),"VMM-COLLATERAL")
val=x~valueContract("VAL-CON-V-1","CON-V",8500000000,"20260930T160000","MKT-INDEPENDENT-SEP","MODEL-INDEPENDENT-SEP","VMM-INDEPENDENT-VALUATION")
call assertNear 15,val~portfolioLossPct,0.000001,"15 percent portfolio loss"
call assertNear 0.5,val~protectionFraction,0.000001,"mid-tranche protection fraction"
call assertNear 5000000000,val~vmmLiabilityMtm,0.01,"VMM liability estimate"
mc=x~issueVariationMarginCall("MC-V-1","CON-V","VAL-CON-V-1","20260930T161000","VMM-COLLATERAL")
call assertNear 4600000000,mc~amount,0.01,"threshold and independent amount applied"
t=.VMMSyntheticCollateralTransfer~new("COLL-V-1","CON-V","MC-V-1","JPY",4600000000,"VMM_TO_COUNTERPARTY","THIRD_PARTY_CUSTODIAN","CONTROL-RECEIPT-V-1","20260930T170000","VMM-COLLATERAL")
x~recordCollateralTransfer(t)
call assertEq "SATISFIED",mc~state,"margin call satisfied by externally evidenced collateral transfer"
call assertNear 4600000000,x~collateralPosted("CON-V"),0.01,"posted collateral retained"
val2=x~valueContract("VAL-CON-V-2","CON-V",8000000000,"20261031T160000","MKT-INDEPENDENT-OCT","MODEL-INDEPENDENT-OCT","VMM-INDEPENDENT-VALUATION")
mc2=x~issueVariationMarginCall("MC-V-2","CON-V","VAL-CON-V-2","20261031T161000","VMM-COLLATERAL")
call assertNear 2500000000,mc2~amount,0.01,"later call credits collateral already posted"
say "PASS test_synthetic_valuation_margin"
exit 0
::routine assertEq
  use strict arg expected,actual,label
  if expected<>actual then raise syntax 88.900 array("ASSERT_EQ",label,"expected",expected,"actual",actual)
::routine assertNear
  use strict arg expected,actual,tolerance,label
  if abs(expected-actual)>tolerance then raise syntax 88.900 array("ASSERT_NEAR",label,"expected",expected,"actual",actual)
::requires "VMMSyntheticProducts.cls"
