v=.VectorMeridianMarkets~new
limits=.VMMFirmRiskLimits~new("RISK-FUND-1","GBP",5000000,2000000,1000000,500000,"POL-FUND-LIMIT")
v~setFirmRiskLimits(limits,"VMM-INDEPENDENT-RISK")
f=.VMMFundingFacility~new("FAC-FIRM-LIMIT","FEDERATIONBANK_MERCHANT_BANK","VECTOR_MERIDIAN_MARKETS_LTD","MERCHANT_CAPITAL","GBP",2000000,500,"LEGAL-FIRM-LOAN","POL-ARM-LENGTH","20271231")
v~registerFundingFacility(f)
v~drawFunding("DRAW-FIRM-1","FAC-FIRM-LIMIT",800000,"20260828T125000","FEDERATIONBANK_MERCHANT_TREASURY","LOAN-OBL-FIRM-1")
call expectFundingLimit v
call assertEq 800000,f~outstanding,"rejected draw does not mutate arm-length debt"
say "PASS test_firm_funding_limit"
exit 0

::routine expectFundingLimit
  use strict arg v
  signal on syntax name gotSyntax
  v~drawFunding("DRAW-FIRM-2","FAC-FIRM-LIMIT",300000,"20260828T125001","FEDERATIONBANK_MERCHANT_TREASURY","LOAN-OBL-FIRM-2")
  signal off syntax
  raise syntax 88.900 array("firm funding limit unexpectedly bypassed")
gotSyntax:
  signal off syntax
  return

::routine assertEq
  use strict arg expected,actual,label
  if expected<>actual then raise syntax 88.900 array("ASSERT_EQ",label,"expected",expected,"actual",actual)

::requires "VectorMeridianMarkets.cls"
