e=.MBDecisionEvidence~new("PERMITTED","PERMITTED","LEGAL-CSA-491","POLICY-COLLATERAL-7")
mb=.FederationBankMerchantBank~new
mb~createPortfolio("MB-PF-817","ALAN_CORP_PENSIONS","GBP")
mb~registerCollateralAgreement(.MBCollateralAgreement~new("CSA-491","ALAN_CORP_PENSIONS","FEDERATIONBANK_MERCHANT_BANK","ALAN_CORP_PENSIONS","MB-PF-817",5000000,"GBP",e))
mb~registerCollateralAsset(.MBCollateralAsset~new("COLL-1","ALAN_CORP_PENSIONS","CORE-ACCOUNT-PENSION-77","CASH_ACCOUNT","GBP",3000000,2000))
mb~acknowledgeCoreControl(.MBCollateralControlReceipt~new("CTRL-1","CSA-491","COLL-1","CORE-AUTH-1","ALAN_CORP_PENSIONS",.true,.true,"FIRST",3000000,"GBP","09:00"))
v=.MBValuationSnapshot~new("VAL-1","MB-PF-817","09:01","GBP",300000,0,21000000,"MKT-SNAPSHOT-991")
mb~recordValuation(v)
policy=.MBRiskPolicy~new("MB-RISK-POLICY-6X",6,1200000,3600)
a=mb~assessMargin("MARG-1","MB-PF-817",v,policy,700000,"09:02")
call assertEq "MARGIN_DEFICIT",a~state,"deficit state"
call assertTrue a~deficit>0,"positive deficit"
call assertTrue a~effectiveLeverage>6,"leverage exceeds policy"
call assertEq 2400000,a~adjustedCollateral,"controlled haircut collateral"
c=mb~issueMarginCall("CALL-1","MARG-1","09:03","10:03")
call assertEq "OPEN",c~state,"margin call open"
i=mb~defaultMarginCall("CALL-1","CLOSE-1","MB-RISK-AUTH-44","10:04")
call assertEq "DEFAULTED",c~state,"margin call defaulted"
call assertEq "REQUIRED",i~state,"close-out required"
call assertEq "MB-PF-817",i~portfolioId,"close-out portfolio"

-- Close-out creates contractual obligations only; no retail Ledger API exists.
o=mb~createSettlementObligation("OBL-1","ALAN_CORP_PENSIONS","FEDERATIONBANK_MERCHANT_BANK","GBP",500000,"CLOSE_OUT","CLOSE-1")
call assertEq "UNSETTLED",o~status,"merchant obligation awaits arm's-length settlement"
call expectNoLedger mb,"merchant authority has no Ledger posting method"

say "PASS test_margin_default_closeout"
exit 0
::routine assertEq
  use strict arg expected,actual,label
  if expected<>actual then raise syntax 88.900 array("ASSERT_EQ",label,"expected",expected,"actual",actual)
::routine assertTrue
  use strict arg actual,label
  if \actual then raise syntax 88.900 array("ASSERT_TRUE",label)
::routine assertFalse
  use strict arg actual,label
  if actual then raise syntax 88.900 array("ASSERT_FALSE",label)
::routine expectNoLedger
  use strict arg target,label
  caught=.false
  signal on syntax name gotNoMethod
  target~postLedger("ANY")
  signal off syntax
  if \caught then raise syntax 88.900 array("ASSERT_EXPECTED_NO_METHOD",label)
  return
gotNoMethod:
  caught=.true
  signal off syntax
  return
::requires "FederationBankMerchantBank.cls"
