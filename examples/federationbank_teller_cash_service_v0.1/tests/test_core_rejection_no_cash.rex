e=.FBTellerCashTestSupport~engine
.FBTellerCashTestSupport~openCustomerAccount(e)
ctx=.FBTellerCashTestSupport~custody
till=.FederationBankTellerTill~new("TILL-04","DOUGLAS","GBP")
.FBTellerCashTestSupport~openTill(till,ctx,1000000)
stack=.FBTellerCashTestSupport~stack(e,till)
svc=.FederationBankTellerCashService~new(stack["channelService"],stack["cashPort"])
req=.FBTellerCashTestSupport~cashRequest("CORENO","WITHDRAWAL",10000)
inst=.FBTellerCashTestSupport~instruction("CORENO",req,"WITHDRAWAL",10000,"TILL-04",ctx)
r=svc~handle(.FBTellerCashTestSupport~envelope("CORENO",req,inst,.FBTellerCashTestSupport~contexts(.FBTellerCashTestSupport~context)))
.FBTellerCashTestSupport~assertTrue(r~ok,"Core rejection is an institutional result, not service transport failure")
.FBTellerCashTestSupport~assertEq("CORE_REJECTED",r~value~state)
.FBTellerCashTestSupport~assertEq(0,e~ledger~balanceMinor("GBP-SRC"),"customer unchanged")
.FBTellerCashTestSupport~assertEq(1000000,till~expectedMinor,"cash not released after Core rejection")
.FBTellerCashTestSupport~pass("Core Banking remains final monetary authority before withdrawal cash release")
::requires "TestSupport.cls"
