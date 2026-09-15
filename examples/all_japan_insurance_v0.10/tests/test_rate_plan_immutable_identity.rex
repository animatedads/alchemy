book=.AllJapanInsuranceRateBook~new
p1=.AJITestSupport~samplePlan("IMMUTABLE-PLAN")
p2=.AJITestSupport~samplePlan("IMMUTABLE-PLAN")
ignored=.AJITestSupport~must(book~addPlan(p1),"first plan")
r=book~addPlan(p2)
ignored=.AJITestSupport~assert(\r~ok & r~code="RATE_PLAN_DUPLICATE","same planRef cannot be republished")
ignored=.AJITestSupport~assert(book~plan("IMMUTABLE-PLAN")~semanticIdentity=p1~semanticIdentity,"original release remains authoritative")
say "PASS rate-plan release identity is immutable"
::requires "TestSupport.cls"
