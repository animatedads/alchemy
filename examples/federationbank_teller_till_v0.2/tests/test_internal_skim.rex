v=.FederationBankTellerTill~new("TILL-04","DOUGLAS","GBP"); c=.FBTillTest~ctx
ignore=v~open(c,.FBTillTest~bundle(50000),.FBTillTest~approval(.nil,"SUP-OPEN"))
i=.FBTillInternalTest~instruction("ITX-OUT","TILL","TILL-04","VAULT","VAULT-1",15000); a=.FBTillInternalTest~approval(i)
r=v~applyInternalCash(i,.FBTillTest~bundle(15000),c,a)
.FBTillTest~assertTrue(r~ok); .FBTillTest~assertEq(35000,v~expectedMinor)
say "PASS: till skim is internal custody movement, not customer cash out"
::requires "TestSupport.cls"
