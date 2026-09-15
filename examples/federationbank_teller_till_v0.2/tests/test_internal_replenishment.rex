v=.FederationBankTellerTill~new("TILL-04","DOUGLAS","GBP"); c=.FBTillTest~ctx
ignore=v~open(c,.FBTillTest~bundle(50000),.FBTillTest~approval(.nil,"SUP-OPEN"))
i=.FBTillInternalTest~instruction("ITX-IN","VAULT","VAULT-1","TILL","TILL-04",20000); a=.FBTillInternalTest~approval(i)
r=v~applyInternalCash(i,.FBTillTest~bundle(20000),c,a)
.FBTillTest~assertTrue(r~ok); .FBTillTest~assertEq(70000,v~expectedMinor)
say "PASS: till replenishment uses explicit internal cash semantics"
::requires "TestSupport.cls"
