e=.FBTellerCashTestSupport~engine
.FBTellerCashTestSupport~openCustomerAccount(e)
.FBTellerCashTestSupport~seedCustomer(e,"GBP-SRC",2000000)
ctx=.FBTellerCashTestSupport~custody
till=.FederationBankTellerTill~new("TILL-04","DOUGLAS","GBP")
.FBTellerCashTestSupport~openTill(till,ctx,1000000)
stack=.FBTellerCashTestSupport~stack(e,till)
svc=.FederationBankTellerCashService~new(stack["channelService"],stack["cashPort"])
staffCtx=.FBTellerCashTestSupport~context
req=.FBTellerCashTestSupport~cashRequest("W1","WITHDRAWAL",10000)
inst=.FBTellerCashTestSupport~instruction("W1",req,"WITHDRAWAL",10000,"TILL-04",ctx)
r=svc~handle(.FBTellerCashTestSupport~envelope("W1",req,inst,.FBTellerCashTestSupport~contexts(staffCtx)))
.FBTellerCashTestSupport~assertTrue(r~ok,"cash withdrawal")
.FBTellerCashTestSupport~assertEq("COMPLETED",r~value~state,"cash work")
.FBTellerCashTestSupport~assertEq(1990000,e~ledger~balanceMinor("GBP-SRC"),"customer debit")
.FBTellerCashTestSupport~assertEq(990000,till~expectedMinor,"physical till release")
.FBTellerCashTestSupport~assertEq("TELLER_CASH_COMPLETED",r~value~outcomeCode,"outcome")
.FBTellerCashTestSupport~pass("customer instruction -> Staff Authority -> Core transfer -> Till cash release")
::requires "TestSupport.cls"
