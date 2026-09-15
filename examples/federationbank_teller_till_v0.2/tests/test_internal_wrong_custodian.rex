v=.FederationBankTellerTill~new("TILL-04","DOUGLAS","GBP"); c=.FBTillTest~ctx
ignore=v~open(c,.FBTillTest~bundle(50000),.FBTillTest~approval(.nil,"SUP-OPEN"))
i=.FBTillInternalTest~instruction("ITX-WRONG","VAULT","V1","TILL","TILL-04",10000); a=.FBTillInternalTest~approval(i); wrong=.FBTillTest~ctx("TELLER-05","TILL-04")
r=v~applyInternalCash(i,.FBTillTest~bundle(10000),wrong,a); .FBTillTest~assertEq("NOT_CUSTODIAN",r~code)
say "PASS: Branch Cash authority does not bypass current till custody"
::requires "TestSupport.cls"
