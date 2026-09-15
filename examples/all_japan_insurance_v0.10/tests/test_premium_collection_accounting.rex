ctx=.AJIAccountingTestSupport~ratedHomeContext
a=ctx["authority"]
p=ctx["policy"]
rating=ctx["rating"]
adapter=.AllJapanInsuranceAccountingAdapter~new(a)
engine=.AJIAccountingTestSupport~accountingEngine
bound=.AJITestSupport~must(adapter~policyBoundEvent(p~policyId,"2026-09-01"),"bound event")~value
.AJITestSupport~assert(engine~transact(bound)~ok,"recognize receivable")
col=.AJITestSupport~must(adapter~premiumCollectedEvent("COLL-1",p~policyId,rating~totalPremiumMinor,"2026-09-02"),"collection event")~value
posted=engine~transact(col)
.AJITestSupport~assert(posted~ok,"collection posts")
.AJITestSupport~assert(engine~book~balance("1000","JPY")~netDebitMinor=rating~totalPremiumMinor,"cash received")
.AJITestSupport~assert(engine~book~balance("1100","JPY")~netDebitMinor=0,"premium receivable clears")
say "PASS JPY premium collection clears premium receivable without rerating policy"
::requires "AccountingTestSupport.cls"
