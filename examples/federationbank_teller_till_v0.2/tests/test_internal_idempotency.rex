v=.FederationBankTellerTill~new("TILL-04","DOUGLAS","GBP"); c=.FBTillTest~ctx
ignore=v~open(c,.FBTillTest~bundle(50000),.FBTillTest~approval(.nil,"SUP-OPEN"))
i=.FBTillInternalTest~instruction("ITX-IDEM","VAULT","V1","TILL","TILL-04",10000); a=.FBTillInternalTest~approval(i)
r1=v~applyInternalCash(i,.FBTillTest~bundle(10000),c,a); r2=v~applyInternalCash(i,.FBTillTest~bundle(10000),c,a)
.FBTillTest~assertTrue(r1~ok & r2~ok); .FBTillTest~assertEq(60000,v~expectedMinor); .FBTillTest~assertEq("IDEMPOTENT_INTERNAL_TRANSFER",r2~detail)
say "PASS: exact internal transfer replay cannot move till cash twice"
::requires "TestSupport.cls"
