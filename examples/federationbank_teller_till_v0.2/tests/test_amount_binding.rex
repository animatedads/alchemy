t=.FederationBankTellerTill~new("TILL-04","DOUGLAS","GBP"); c=.FBTillTest~ctx; t~open(c,.FBTillTest~bundle(100000),.FBTillTest~approval)
a=.FederationBankTillAction~new("ACT","CASH_OUT",1000,"GBP","TELLER-04","C1","A1","CMD")
r=t~applyCash(a,.FBTillTest~bundle(900),c); .FBTillTest~assertEq("COUNT_AMOUNT_MISMATCH",r~code); say "PASS: counted physical cash must equal authorised action amount"
::requires "TestSupport.cls"
