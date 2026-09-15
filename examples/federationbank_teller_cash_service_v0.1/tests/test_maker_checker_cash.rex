e=.FBTellerCashTestSupport~engine
.FBTellerCashTestSupport~openCustomerAccount(e)
.FBTellerCashTestSupport~seedCustomer(e,"GBP-SRC",2000000)
ctx=.FBTellerCashTestSupport~custody
till=.FederationBankTellerTill~new("TILL-04","DOUGLAS","GBP")
.FBTellerCashTestSupport~openTill(till,ctx,1000000)
stack=.FBTellerCashTestSupport~stack(e,till)
svc=.FederationBankTellerCashService~new(stack["channelService"],stack["cashPort"])
teller=.FBTellerCashTestSupport~context
req=.FBTellerCashTestSupport~cashRequest("HV","WITHDRAWAL",600000)
base=.FBTellerCashTestSupport~instruction("HV",req,"WITHDRAWAL",600000,"TILL-04",ctx)
tillAp=.FBTellerCashTestExtensions~tillApproval(base,req)
inst=.FBTellerCashTestSupport~instruction("HV",req,"WITHDRAWAL",600000,"TILL-04",ctx,"FB-SETTLEMENT-GBP",tillAp)
r1=svc~handle(.FBTellerCashTestSupport~envelope("HV",req,inst,.FBTellerCashTestSupport~contexts(teller)))
.FBTellerCashTestSupport~assertTrue(r1~ok,"approval workflow is accepted")
.FBTellerCashTestSupport~assertEq("APPROVAL_REQUIRED",r1~value~state)
.FBTellerCashTestSupport~assertEq(2000000,e~ledger~balanceMinor("GBP-SRC"),"no Core movement before checker")
sup=.FBTellerCashTestExtensions~supervisorContext
sap=.FBTellerCashTestExtensions~staffApproval(req)
approvals=.array~of(sap)
r2=svc~handle(.FBTellerCashTestExtensions~resumeEnvelope("HV-RESUME",r1~workId,.FBTellerCashTestSupport~contexts(teller,sup),approvals))
.FBTellerCashTestSupport~assertTrue(r2~ok,"resume")
.FBTellerCashTestSupport~assertEq("COMPLETED",r2~value~state)
.FBTellerCashTestSupport~assertEq(1400000,e~ledger~balanceMinor("GBP-SRC"),"Core debit after checker")
.FBTellerCashTestSupport~assertEq(400000,till~expectedMinor,"physical release after both controls")
.FBTellerCashTestSupport~pass("staff maker/checker and physical till checker remain independent controls")
::requires "TestSupport.cls"
