e=.MBDecisionEvidence~new("PERMITTED","PERMITTED","LEGAL-491","POLICY-7")
mb=.FederationBankMerchantBank~new
mb~createPortfolio("MB-PF-817","ALAN_CORP_PENSIONS","GBP")
mb~registerCollateralAgreement(.MBCollateralAgreement~new("CSA-491","ALAN_CORP_PENSIONS","FEDERATIONBANK_MERCHANT_BANK","ALAN_CORP_PENSIONS","MB-PF-817",5000000,"GBP",e))
mb~registerCollateralAsset(.MBCollateralAsset~new("COLL-1","ALAN_CORP_PENSIONS","CORE-ACCOUNT-PENSION-77","CASH_ACCOUNT","GBP",3000000,2000))
q=.FBCollateralControlRequest~new("REQ-1","FEDERATIONBANK_MERCHANT_BANK","CSA-491","ALAN_CORP_PENSIONS","ALAN_CORP_PENSIONS","MB-PF-817","CORE-ACCOUNT-PENSION-77",3000000,"GBP","LEGAL-491","POLICY-7","09:00")
d=.FBCollateralControlDecision~new("DEC-1","REQ-1",.true,"CORE-AUTH-1","ALAN_CORP_PENSIONS","ENC-99",.true,.true,"FIRST",3000000,"GBP","09:01")
a=.FBMerchantCollateralAdapter~new
r=a~acceptControlDecision(mb,q,d,"COLL-1")
call assertEq "CORE-AUTH-1",r~coreAuthorityRef,"Core authority retained"
c=mb~controlledCollateral("MB-PF-817","GBP")
call assertEq 2400000,c["adjusted"],"protocol decision becomes haircut-adjusted controlled collateral"
say "PASS test_protocol_to_book"
exit 0
::routine assertEq
 use strict arg expected,actual,label
 if expected<>actual then raise syntax 88.900 array("ASSERT_EQ",label,"expected",expected,"actual",actual)
::requires "FederationBankMerchantCollateralAdapter.cls"
