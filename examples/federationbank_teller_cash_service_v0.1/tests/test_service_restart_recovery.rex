e=.FBTellerCashTestSupport~engine
.FBTellerCashTestSupport~openCustomerAccount(e)
.FBTellerCashTestSupport~seedCustomer(e,"GBP-SRC",2000000)
ctx=.FBTellerCashTestSupport~custody
till=.FederationBankTellerTill~new("TILL-04","DOUGLAS","GBP")
.FBTellerCashTestSupport~openTill(till,ctx,1000000)
stack=.FBTellerCashTestSupport~stack(e,till)
root="/tmp/fbtelcash-state-"||time("S")||"-"||random(100000,999999)
store=.FederationBankTellerCashServiceStore~new(root)
svc1=.FederationBankTellerCashService~new(stack["channelService"],stack["cashPort"],store)
req=.FBTellerCashTestSupport~cashRequest("RST","WITHDRAWAL",10000)
inst=.FBTellerCashTestSupport~instruction("RST",req,"WITHDRAWAL",10000,"TILL-04",ctx)
r=svc1~handle(.FBTellerCashTestSupport~envelope("RST",req,inst,.FBTellerCashTestSupport~contexts(.FBTellerCashTestSupport~context)))
.FBTellerCashTestSupport~assertTrue(r~ok)
svc2=.FederationBankTellerCashService~new(stack["channelService"],stack["cashPort"],store)
w=svc2~work("CASHWORK:RST")
.FBTellerCashTestSupport~assertTrue(w<>.nil,"work recovered")
.FBTellerCashTestSupport~assertEq("COMPLETED",w~state)
.FBTellerCashTestSupport~assertEq(inst~semanticIdentity,w~instruction~semanticIdentity,"exact instruction recovered")
.FBTellerCashTestSupport~pass("typed Teller Cash service state survives durable restart")
::requires "FederationBankTellerCashServicePersistence.cls"
::requires "TestSupport.cls"
