v=.FederationBankTellerTill~new("TILL-04","DOUGLAS","GBP"); c=.FBTillTest~ctx
ignore=v~open(c,.FBTillTest~bundle(50000),.FBTillTest~approval(.nil,"SUP-OPEN"))
i1=.FBTillInternalTest~instruction("ITX-1","VAULT","V1","TILL","TILL-04",10000); i2=.FBTillInternalTest~instruction("ITX-2","VAULT","V1","TILL","TILL-04",20000); a=.FBTillInternalTest~approval(i1)
r=v~applyInternalCash(i2,.FBTillTest~bundle(20000),c,a)
.FBTillTest~assertEq("APPROVAL_ACTION_MISMATCH",r~code)
say "PASS: internal till checker approval binds to exact transfer"
::requires "TestSupport.cls"
