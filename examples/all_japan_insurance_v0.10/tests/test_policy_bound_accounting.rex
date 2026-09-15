ctx=.AJIAccountingTestSupport~ratedHomeContext
a=ctx["authority"]
rating=ctx["rating"]
p=ctx["policy"]
adapter=.AllJapanInsuranceAccountingAdapter~new(a)
er=adapter~policyBoundEvent(p~policyId,"2026-09-01","AJI-ECONOMIC-POLICY-1","CUSTOMER-JP-1","COMMISSION_PAYABLE")
.AJITestSupport~must(er,"build policy-bound accounting event")
event=er~value
.AJITestSupport~assert(event~value("currency")="JPY","policy-bound event JPY")
.AJITestSupport~assert(event~value("totalPremiumMinor")=rating~totalPremiumMinor,"event preserves rated total")
.AJITestSupport~assert(event~value("riskPremiumMinor")+event~value("salesCostMinor")+event~value("taxMinor")=event~value("totalPremiumMinor"),"premium split balances")
engine=.AJIAccountingTestSupport~accountingEngine
tr=engine~transact(event)
.AJITestSupport~assert(tr~ok,"policy-bound event posts")
.AJITestSupport~assert(tr~entry~policyIdentity=.AllJapanInsuranceAccountingBuild~POLICY_BOUND_IDENTITY,"accounting executable identity retained")
.AJITestSupport~assert(engine~book~balance("1100","JPY")~netDebitMinor=rating~totalPremiumMinor,"premium receivable equals gross quote")
.AJITestSupport~assert(engine~book~balance("2210","JPY")~creditMinor=event~value("salesCostMinor"),"commission payable separated")
.AJITestSupport~assert(engine~book~balance("2220","JPY")~creditMinor=event~value("taxMinor"),"tax payable separated")
.AJITestSupport~assert(engine~book~balance("2200","JPY")~creditMinor=event~value("riskPremiumMinor"),"risk premium stays in insurance control account")
say "PASS rated JPY policy decomposes into AJI accounting control balances"
::requires "AccountingTestSupport.cls"
