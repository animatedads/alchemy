t=.FederationBankTellerTill~new("TILL-04","DOUGLAS","GBP"); c=.FBTillTest~ctx; t~open(c,.FBTillTest~bundle(2000000),.FBTillTest~approval)
a=.FederationBankTillAction~new("ACT-HIGH","CASH_OUT",600000,"GBP","TELLER-04","C1","A1","CMD3")
r=t~applyCash(a,.FBTillTest~bundle(600000),c); .FBTillTest~assertEq("CHECKER_REQUIRED",r~code)
ap=.FBTillTest~approval(a,"SUP-02"); r=t~applyCash(a,.FBTillTest~bundle(600000),c,ap); .FBTillTest~assertTrue(r~ok)
say "PASS: high-value cash movement requires exact-action checker"
::requires "TestSupport.cls"
