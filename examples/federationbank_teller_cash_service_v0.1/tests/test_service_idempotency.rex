e=.FBTellerCashTestSupport~engine
.FBTellerCashTestSupport~openCustomerAccount(e)
.FBTellerCashTestSupport~seedCustomer(e,"GBP-SRC",2000000)
ctx=.FBTellerCashTestSupport~custody
till=.FederationBankTellerTill~new("TILL-04","DOUGLAS","GBP")
.FBTellerCashTestSupport~openTill(till,ctx,1000000)
stack=.FBTellerCashTestSupport~stack(e,till)
svc=.FederationBankTellerCashService~new(stack["channelService"],stack["cashPort"])
req=.FBTellerCashTestSupport~cashRequest("IDEM","WITHDRAWAL",10000)
inst=.FBTellerCashTestSupport~instruction("IDEM",req,"WITHDRAWAL",10000,"TILL-04",ctx)
env=.FBTellerCashTestSupport~envelope("IDEM",req,inst,.FBTellerCashTestSupport~contexts(.FBTellerCashTestSupport~context))
r1=svc~handle(env); b1=e~ledger~balanceMinor("GBP-SRC"); cash1=till~expectedMinor
r2=svc~handle(env)
.FBTellerCashTestSupport~assertTrue(r1~ok)
.FBTellerCashTestSupport~assertTrue(r2~ok)
.FBTellerCashTestSupport~assertEq("IDEMPOTENT_REPLAY",r2~code)
.FBTellerCashTestSupport~assertEq(b1,e~ledger~balanceMinor("GBP-SRC"),"one Core movement")
.FBTellerCashTestSupport~assertEq(cash1,till~expectedMinor,"one physical movement")
.FBTellerCashTestSupport~pass("Teller Cash service command idempotency spans monetary and physical effects")
::requires "TestSupport.cls"
