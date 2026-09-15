e=.FBTellerCashTestSupport~engine
.FBTellerCashTestSupport~openCustomerAccount(e)
.FBTellerCashTestSupport~seedCustomer(e,"GBP-SRC",2000000)
ctx=.FBTellerCashTestSupport~custody
till=.FederationBankTellerTill~new("TILL-04","DOUGLAS","GBP")
.FBTellerCashTestSupport~openTill(till,ctx,5000)
stack=.FBTellerCashTestSupport~stack(e,till)
svc=.FederationBankTellerCashService~new(stack["channelService"],stack["cashPort"])
req=.FBTellerCashTestSupport~cashRequest("COMP","WITHDRAWAL",10000)
inst=.FBTellerCashTestSupport~instruction("COMP",req,"WITHDRAWAL",10000,"TILL-04",ctx)
r=svc~handle(.FBTellerCashTestSupport~envelope("COMP",req,inst,.FBTellerCashTestSupport~contexts(.FBTellerCashTestSupport~context)))
.FBTellerCashTestSupport~assertTrue(r~ok,"compensation is durable institutional work")
.FBTellerCashTestSupport~assertEq("COMPENSATION_REQUIRED",r~value~state)
.FBTellerCashTestSupport~assertEq(1990000,e~ledger~balanceMinor("GBP-SRC"),"Core debit already committed")
.FBTellerCashTestSupport~assertEq(5000,till~expectedMinor,"physical cash was not released")
.FBTellerCashTestSupport~pass("post-Core physical failure is explicit compensation work, never generic failure")
::requires "TestSupport.cls"
