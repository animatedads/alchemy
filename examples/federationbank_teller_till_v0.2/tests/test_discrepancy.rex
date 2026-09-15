t=.FederationBankTellerTill~new("TILL-04","DOUGLAS","GBP"); c=.FBTillTest~ctx; t~open(c,.FBTillTest~bundle(100000),.FBTillTest~approval)
r=t~close(c,.FBTillTest~bundle(99900),.FBTillTest~approval); .FBTillTest~assertEq("TILL_DISCREPANCY_REQUIRES_RESOLUTION",r~code); .FBTillTest~assertEq(-100,t~discrepancyMinor)
say "PASS: discrepancy blocks closure and remains explicit"
::requires "TestSupport.cls"
