t=.FederationBankTellerTill~new("TILL-04","DOUGLAS","GBP"); c=.FBTillTest~ctx; t~open(c,.FBTillTest~bundle(100000),.FBTillTest~approval)
a=.FederationBankTillAction~new("ACT","CASH_OUT",100,"GBP","OTHER","C1","A1","CMD")
r=t~applyCash(a,.FBTillTest~bundle(100),.FBTillTest~ctx("OTHER")); .FBTillTest~assertEq("NOT_CUSTODIAN",r~code); say "PASS: custody is bound to the assigned teller"
::requires "TestSupport.cls"
