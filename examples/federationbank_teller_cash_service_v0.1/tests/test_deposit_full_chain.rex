e=.FBTellerCashTestSupport~engine
.FBTellerCashTestSupport~openCustomerAccount(e)
.FBTellerCashTestSupport~seedCustomer(e,"GBP-SRC",2000000)
ctx=.FBTellerCashTestSupport~custody
till=.FederationBankTellerTill~new("TILL-04","DOUGLAS","GBP")
.FBTellerCashTestSupport~openTill(till,ctx,1000000)
stack=.FBTellerCashTestSupport~stack(e,till)
svc=.FederationBankTellerCashService~new(stack["channelService"],stack["cashPort"])
staffCtx=.FBTellerCashTestSupport~context
req=.FBTellerCashTestSupport~cashRequest("D1","DEPOSIT",5000)
inst=.FBTellerCashTestSupport~instruction("D1",req,"DEPOSIT",5000,"TILL-04",ctx)
r=svc~handle(.FBTellerCashTestSupport~envelope("D1",req,inst,.FBTellerCashTestSupport~contexts(staffCtx)))
.FBTellerCashTestSupport~assertTrue(r~ok,"cash deposit")
.FBTellerCashTestSupport~assertEq("COMPLETED",r~value~state,"cash work")
.FBTellerCashTestSupport~assertEq(2005000,e~ledger~balanceMinor("GBP-SRC"),"customer credit")
.FBTellerCashTestSupport~assertEq(1005000,till~expectedMinor,"physical till acceptance")
.FBTellerCashTestSupport~pass("cash accepted -> Core customer credit with independent authorities retained")
::requires "TestSupport.cls"
