e=.MBDecisionEvidence~new("PERMITTED","PERMITTED","LEGAL-CSA-491","POLICY-COLLATERAL-7")
mb=.FederationBankMerchantBank~new("FEDERATIONBANK_MERCHANT_BANK")
p=mb~createPortfolio("MB-PF-817","ALAN_CORP_PENSIONS","GBP")
a=.MBCollateralAgreement~new("CSA-491","ALAN_CORP_PENSIONS","FEDERATIONBANK_MERCHANT_BANK","ALAN_CORP_PENSIONS","MB-PF-817",5000000,"GBP",e)
mb~registerCollateralAgreement(a)
asset=.MBCollateralAsset~new("COLL-1","ALAN_CORP_PENSIONS","CORE-ACCOUNT-PENSION-77","CASH_ACCOUNT","GBP",3000000,2000)
mb~registerCollateralAsset(asset)

-- Merely registering an asset does not make it eligible collateral.
c=mb~controlledCollateral("MB-PF-817","GBP")
call assertEq 0,c["gross"],"uncontrolled retail/Core asset is not merchant collateral"

r=.MBCollateralControlReceipt~new("CTRL-1","CSA-491","COLL-1","CORE-COLLATERAL-AUTH-1001","ALAN_CORP_PENSIONS",.true,.true,"FIRST",3000000,"GBP","20260826T090000")
mb~acknowledgeCoreControl(r)
c=mb~controlledCollateral("MB-PF-817","GBP")
call assertEq 3000000,c["gross"],"Core acknowledged gross collateral"
call assertEq 2400000,c["adjusted"],"haircut adjusted collateral"

-- Cross-entity leakage must fail.
bad=.MBCollateralControlReceipt~new("CTRL-X","CSA-491","COLL-1","CORE-COLLATERAL-AUTH-X","ALAN_CORP",.true,.true,"FIRST",100000,"GBP","20260826T090100")
call expectSyntax mb,"ACKNOWLEDGECORECONTROL",bad,"cross-entity control rejected"

say "PASS test_arm_length_collateral"
exit 0

::routine assertEq
  use strict arg expected,actual,label
  if expected<>actual then raise syntax 88.900 array("ASSERT_EQ",label,"expected",expected,"actual",actual)
::routine expectSyntax
  use strict arg target,method,arg1,label
  caught=.false
  signal on syntax name gotSyntax
  target~sendWith(method,.array~of(arg1))
  signal off syntax
  if \caught then raise syntax 88.900 array("ASSERT_EXPECTED_SYNTAX",label)
  return
gotSyntax:
  caught=.true
  signal off syntax
  return
::requires "FederationBankMerchantBank.cls"
