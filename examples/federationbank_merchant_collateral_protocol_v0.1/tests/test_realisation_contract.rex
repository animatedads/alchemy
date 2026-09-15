v=.FBMerchantCollateralProtocolValidator~new
q=.FBCollateralRealisationRequest~new("REAL-1","FEDERATIONBANK_MERCHANT_BANK","CSA-491","ENC-99","MB-PF-817","DEFAULT-22","CLOSE-22",500000,"GBP","LEGAL-REALISE-22","14:05")
d=.FBCollateralRealisationDecision~new("RDEC-1","REAL-1",.true,"CORE-AUTH-REAL-1",500000,"GBP","CORE-SETTLEMENT-881","14:06")
call assertTrue v~validateRealisationDecision(q,d),"Core realisation acknowledged"

over=.FBCollateralRealisationDecision~new("RDEC-2","REAL-1",.true,"CORE-AUTH-REAL-2",600000,"GBP","CORE-SETTLEMENT-882","14:06")
call expectSyntax v,"VALIDATEREALISATIONDECISION",q,over,"Core cannot realise more than requested"
say "PASS test_realisation_contract"
exit 0
::routine assertTrue
 use strict arg x,label
 if \x then raise syntax 88.900 array("ASSERT_TRUE",label)
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
