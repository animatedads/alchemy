v=.FBMerchantCollateralProtocolValidator~new
q=.FBCollateralControlRequest~new("REQ-1","FEDERATIONBANK_MERCHANT_BANK","CSA-491","ALAN_CORP_PENSIONS","ALAN_CORP_PENSIONS","MB-PF-817","CORE-ACCOUNT-PENSION-77",3000000,"GBP","LEGAL-491","POLICY-7","09:00")
d=.FBCollateralControlDecision~new("DEC-1","REQ-1",.true,"CORE-AUTH-1","ALAN_CORP_PENSIONS","ENC-99",.true,.true,"FIRST",3000000,"GBP","09:01")
call assertTrue v~validateControlDecision(q,d),"matching Core acknowledgement accepted"

badOwner=.FBCollateralControlDecision~new("DEC-2","REQ-1",.true,"CORE-AUTH-2","ALAN_CORP","ENC-100",.true,.true,"FIRST",100000,"GBP","09:01")
call expectSyntax v,"VALIDATECONTROLDECISION",q,badOwner,"cross-entity Core acknowledgement rejected"

badAmount=.FBCollateralControlDecision~new("DEC-3","REQ-1",.true,"CORE-AUTH-3","ALAN_CORP_PENSIONS","ENC-101",.true,.true,"FIRST",3100000,"GBP","09:01")
call expectSyntax v,"VALIDATECONTROLDECISION",q,badAmount,"Core cannot acknowledge more than requested"

rejected=.FBCollateralControlDecision~new("DEC-4","REQ-1",.false,"CORE-AUTH-4","","",.false,.false,"",0,"GBP","09:01","PENSION_ASSET_NOT_PLEDGEABLE")
call assertFalse v~validateControlDecision(q,rejected),"Core rejection remains authoritative"
say "PASS test_control_contract"
exit 0
::routine assertTrue
 use strict arg x,label
 if \x then raise syntax 88.900 array("ASSERT_TRUE",label)
::routine assertFalse
 use strict arg x,label
 if x then raise syntax 88.900 array("ASSERT_FALSE",label)
::routine expectSyntax
 use strict arg target,method,a,b,label
 caught=.false
 signal on syntax name gotSyntax
 target~sendWith(method,.array~of(a,b))
 signal off syntax
 if \caught then raise syntax 88.900 array("ASSERT_EXPECTED_SYNTAX",label)
 return
gotSyntax:
 caught=.true
 signal off syntax
 return
::requires "FederationBankMerchantCollateralProtocol.cls"
