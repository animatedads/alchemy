ctx=.AJIAccountingTestSupport~ratedHomeContext
a=ctx["authority"]
p=ctx["policy"]
ci=.AJITestSupport~actor("CLAIMS-INTAKE",.AllJapanInsuranceBuild~ROLE_CLAIMS_INTAKE)
ca=.AJITestSupport~actor("CLAIMS-ASSESSOR",.AllJapanInsuranceBuild~ROLE_CLAIMS_ASSESSOR)
claim=.AllJapanInsuranceClaim~new("C-JPY-1",p~policyId,"CUSTOMER-JP-1","2026-10-01","2026-10-02T09:00:00","LOSS-JPY-1")
.AJITestSupport~must(a~openClaim(ci,claim),"open JPY claim")
ass1=.AJITestSupport~must(a~assessClaim(ca,"A-JPY-1",claim~claimId,80000,"2026-10-03T10:00:00","EVID-CLAIM-1"),"assess claim 1")~value
adapter=.AllJapanInsuranceAccountingAdapter~new(a)
engine=.AJIAccountingTestSupport~accountingEngine
ev1=.AJITestSupport~must(adapter~claimReserveChangedEvent(ass1~assessmentId,0,"2026-10-03","CLAIM-CORR-1"),"reserve event 1")~value
post1=engine~transact(ev1)
.AJITestSupport~assert(post1~ok,"initial reserve posts")
.AJITestSupport~assert(engine~book~balance("2230","JPY")~creditMinor=ass1~payableMinor,"claims outstanding established")
ass2=.AJITestSupport~must(a~assessClaim(ca,"A-JPY-2",claim~claimId,50000,"2026-10-05T10:00:00","EVID-CLAIM-2"),"assess claim 2")~value
ev2=.AJITestSupport~must(adapter~claimReserveChangedEvent(ass2~assessmentId,ass1~payableMinor,"2026-10-05","CLAIM-CORR-1"),"reserve event 2")~value
.AJITestSupport~assert(ev2~value("reserveDeltaMinor")<0,"lower assessment creates release delta")
post2=engine~transact(ev2)
.AJITestSupport~assert(post2~ok,"reserve release posts")
.AJITestSupport~assert(engine~book~balance("2230","JPY")~netDebitMinor=-ass2~payableMinor,"claims liability net credit equals latest payable")
say "PASS claim assessments create explicit JPY reserve increases and releases"
::requires "AccountingTestSupport.cls"
