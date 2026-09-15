t=.FederationBankTellerTill~new("TILL-04","DOUGLAS","GBP"); c=.FBTillTest~ctx; a=.FBTillTest~approval
t~open(c,.FBTillTest~bundle(1000000),a)
in=.FederationBankTillAction~new("ACT-IN","CASH_IN",12500,"GBP","TELLER-04","C1","A1","CMD1")
r=t~applyCash(in,.FBTillTest~bundle(12500),c); .FBTillTest~assertTrue(r~ok)
out=.FederationBankTillAction~new("ACT-OUT","CASH_OUT",5000,"GBP","TELLER-04","C1","A1","CMD2")
r=t~applyCash(out,.FBTillTest~bundle(5000),c); .FBTillTest~assertTrue(r~ok)
.FBTillTest~assertEq(1007500,t~expectedMinor); say "PASS: physical cash custody moves independently of banking ledger"
::requires "TestSupport.cls"
