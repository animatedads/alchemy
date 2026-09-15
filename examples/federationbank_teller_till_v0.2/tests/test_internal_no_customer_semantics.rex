i=.FBTillInternalTest~instruction("ITX-NOCUST","VAULT","V1","TILL","TILL-04",10000)
.FBTillTest~assertTrue(\i~hasMethod("CUSTOMERID")); .FBTillTest~assertTrue(\i~hasMethod("ACCOUNTID")); .FBTillTest~assertTrue(\i~hasMethod("BANKINGCOMMANDID"))
say "PASS: internal till movement carries no customer/Core transaction fields"
::requires "TestSupport.cls"
