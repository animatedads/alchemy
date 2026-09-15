e=.FBTellerCashTestSupport~engine
.FBTellerCashTestSupport~openCustomerAccount(e)
.FBTellerCashTestSupport~seedCustomer(e,"GBP-SRC",2000000)
ctx=.FBTellerCashTestSupport~custody
till=.FederationBankTellerTill~new("TILL-04","DOUGLAS","GBP")
.FBTellerCashTestSupport~openTill(till,ctx,1000000)
stack=.FBTellerCashTestSupport~stack(e,till)
sink=.FederationBankTellerCashMemoryEventSink~new; sink~failNext
svc=.FederationBankTellerCashService~new(stack["channelService"],stack["cashPort"],.nil,sink)
req=.FBTellerCashTestSupport~cashRequest("EVT","WITHDRAWAL",10000)
inst=.FBTellerCashTestSupport~instruction("EVT",req,"WITHDRAWAL",10000,"TILL-04",ctx)
r=svc~handle(.FBTellerCashTestSupport~envelope("EVT",req,inst,.FBTellerCashTestSupport~contexts(.FBTellerCashTestSupport~context)))
.FBTellerCashTestSupport~assertTrue(r~ok,"primary cash work commits despite event sink outage")
.FBTellerCashTestSupport~assertEq(1,svc~state~outbox~items,"event retained")
f=svc~flushOutbox
.FBTellerCashTestSupport~assertTrue(f~ok,"event retry")
.FBTellerCashTestSupport~assertEq(0,svc~state~outbox~items,"outbox cleared")
.FBTellerCashTestSupport~assertEq(1,sink~events~items,"event delivered once")
.FBTellerCashTestSupport~pass("Teller Cash events are at-least-once without rolling back committed work")
::requires "TestSupport.cls"
