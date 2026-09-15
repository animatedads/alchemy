t=.FederationBankTellerTill~new("TILL-04","DOUGLAS","GBP"); c=.FBTillTest~ctx
r=t~open(c,.FBTillTest~bundle(100000),.FBTillTest~approval); .FBTillTest~assertTrue(r~ok)
r=t~close(c,.FBTillTest~bundle(100000),.FBTillTest~approval); .FBTillTest~assertTrue(r~ok)
.FBTillTest~assertEq("CLOSED",t~status); say "PASS: open/count/close with dual control"
::requires "TestSupport.cls"
