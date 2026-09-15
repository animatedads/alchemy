.AJITestSupport~assert(.AccountingSettlementMath~roundToQuantum(103,5,"HALF_EVEN")=105,"Accounting Core v0.7 settlement-rounding API is available")
exact=.AccountingTaxExactAmount~fromBasisRate(12345,5,100)
.AJITestSupport~assert(exact~toMinorUnits("HALF_UP")=617,"Accounting Core v0.7 exact-rational tax arithmetic remains available")
ctx=.AJIAccountingTestSupport~ratedHomeContext
engine=.AJIAccountingTestSupport~accountingEngine
adapter=.AllJapanInsuranceAccountingAdapter~new(ctx["authority"])
ev=.AJITestSupport~must(adapter~policyBoundEvent(ctx["policy"]~policyId,"2026-09-01"),"AJI event")~value
.AJITestSupport~assert(engine~transact(ev)~ok,"AJI v0.10 accounting policies remain compatible with Accounting Core v0.7 transaction path")
say "PASS AJI consumes Accounting Core v0.7 while retaining ordinary event/transaction accounting semantics"
::requires "AccountingTestSupport.cls"
::requires "AccountingTax.cls"
::requires "AccountingSettlement.cls"
