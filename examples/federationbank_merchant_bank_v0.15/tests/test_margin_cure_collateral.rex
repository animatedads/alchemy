e=.MBDecisionEvidence~new("PERMITTED","PERMITTED","LEGAL-CSA-CURE","POL-COLL-CURE")
mb=.FederationBankMerchantBank~new
mb~createPortfolio("PF-COLL","CLIENT-COLL","GBP")
mb~registerCollateralAgreement(.MBCollateralAgreement~new("CSA-CURE","CLIENT-COLL","FEDERATIONBANK_MERCHANT_BANK","CLIENT-COLL","PF-COLL",3000000,"GBP",e))
mb~registerCollateralAsset(.MBCollateralAsset~new("COLL-A","CLIENT-COLL","CORE-A","CASH_ACCOUNT","GBP",1000000,0))
mb~acknowledgeCoreControl(.MBCollateralControlReceipt~new("CTRL-A","CSA-CURE","COLL-A","CORE-AUTH-A","CLIENT-COLL",.true,.true,"FIRST",1000000,"GBP","09:00"))
v=.MBValuationSnapshot~new("VAL-COLL-1","PF-COLL","09:01","GBP",0,0,12000000,"MKT-COLL-1")
mb~recordValuation(v)
policy=.MBRiskPolicy~new("POL-RISK-COLL",6,0,3600)
a1=mb~assessMargin("ASS-COLL-1","PF-COLL",v,policy,0,"09:02")
call assertEq "MARGIN_DEFICIT",a1~state,"initial collateral deficit"
call assertEq 1000000,a1~deficit,"one million collateral cure needed"
c=mb~issueMarginCall("CALL-COLL-1","ASS-COLL-1","09:03","10:03")

mb~registerCollateralAsset(.MBCollateralAsset~new("COLL-B","CLIENT-COLL","CORE-B","CASH_ACCOUNT","GBP",1000000,0))
ctrlB=.MBCollateralControlReceipt~new("CTRL-B","CSA-CURE","COLL-B","CORE-AUTH-B","CLIENT-COLL",.true,.true,"FIRST",1000000,"GBP","09:20")
mb~acknowledgeCoreControl(ctrlB)
a2=mb~assessMargin("ASS-COLL-2","PF-COLL",v,policy,0,"09:21")
call assertEq "COMPLIANT",a2~state,"new Core-acknowledged collateral cures leverage"
r=mb~cureMarginCall("CALL-COLL-1","CURE-COLL-1","COLLATERAL","CTRL-B","CORE-AUTH-B","ASS-COLL-2","09:22")
call assertEq "CURED",c~state,"collateral call cured"
call assertEq "COLLATERAL",r~mechanism,"collateral mechanism retained"

-- A second receipt cannot double-count the same Core asset/agreement.
duplicate=.MBCollateralControlReceipt~new("CTRL-B2","CSA-CURE","COLL-B","CORE-AUTH-B2","CLIENT-COLL",.true,.true,"FIRST",100000,"GBP","09:23")
call expectSyntax mb,"ACKNOWLEDGECORECONTROL",.array~of(duplicate),"duplicate asset control rejected"

say "PASS test_margin_cure_collateral"
exit 0
::routine assertEq
  use strict arg expected,actual,label
  if expected<>actual then raise syntax 88.900 array("ASSERT_EQ",label,"expected",expected,"actual",actual)
::routine expectSyntax
  use strict arg target,method,args,label
  caught=.false
  signal on syntax name gotSyntax
  target~sendWith(method,args)
  signal off syntax
  if \caught then raise syntax 88.900 array("ASSERT_EXPECTED_SYNTAX",label)
  return
gotSyntax:
  caught=.true
  signal off syntax
  return
::requires "FederationBankMerchantBank.cls"
