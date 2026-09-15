e=.FBTellerCashTestSupport~engine
.FBTellerCashTestSupport~openCustomerAccount(e)
.FBTellerCashTestSupport~seedCustomer(e,"GBP-SRC",2000000)
ctx=.FBTellerCashTestSupport~custody
till=.FederationBankTellerTill~new("TILL-04","DOUGLAS","GBP")
.FBTellerCashTestSupport~openTill(till,ctx,1000000)
stack=.FBTellerCashTestSupport~stack(e,till)
svc=.FederationBankTellerCashService~new(stack["channelService"],stack["cashPort"])
staffCtx=.FBTellerCashTestSupport~context
req=.FBTellerCashTestSupport~cashRequest("NATM","WITHDRAWAL",10000)
inst=.FBTellerCashTestSupport~instruction("NATM",req,"WITHDRAWAL",10000,"TILL-04",ctx)
r=svc~handle(.FBTellerCashTestSupport~envelope("NATM",req,inst,.FBTellerCashTestSupport~contexts(staffCtx)))
.FBTellerCashTestSupport~assertTrue(r~ok)
/* No ATM hold/authorization path is used: Core transfer evidence records the teller cash origin. */
tr=e~ledger~transactionPostings("CORE:CASHIDEM:NATM")
.FBTellerCashTestSupport~assertEq(2,tr~items,"ordinary two-leg transfer postings")
.FBTellerCashTestSupport~pass("counter cash is not routed through ATM withdrawal/hold semantics")
::requires "TestSupport.cls"
