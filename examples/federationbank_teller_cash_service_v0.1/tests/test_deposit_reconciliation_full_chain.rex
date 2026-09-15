e=.FBTellerCashTestSupport~engine
ctx=.FBTellerCashTestSupport~custody
till=.FederationBankTellerTill~new("TILL-04","DOUGLAS","GBP")
.FBTellerCashTestSupport~openTill(till,ctx,1000000)
stack=.FBTellerCashTestSupport~stack(e,till)
svc=.FederationBankTellerCashService~new(stack["channelService"],stack["cashPort"])
req=.FBTellerCashTestSupport~cashRequest("RECON","DEPOSIT",5000,"TELLER-04","S-TEL","GBP-MISSING")
inst=.FBTellerCashTestSupport~instruction("RECON",req,"DEPOSIT",5000,"TILL-04",ctx)
r=svc~handle(.FBTellerCashTestSupport~envelope("RECON",req,inst,.FBTellerCashTestSupport~contexts(.FBTellerCashTestSupport~context)))
.FBTellerCashTestSupport~assertTrue(r~ok,"reconciliation is accepted work")
.FBTellerCashTestSupport~assertEq("RECONCILIATION_REQUIRED",r~value~state)
.FBTellerCashTestSupport~assertEq(1005000,till~expectedMinor,"customer cash remains in bank custody")
.FBTellerCashTestSupport~pass("cash accepted without Core credit becomes explicit reconciliation work")
::requires "TestSupport.cls"
