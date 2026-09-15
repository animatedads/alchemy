book=.AllJapanInsuranceRateBook~new
p1=.AJITestSupport~samplePlan("P1","2026-01-01","")
p2=.AJITestSupport~samplePlan("P2","2026-06-01","")
ignored=.AJITestSupport~must(book~addPlan(p1),"p1")
ignored=.AJITestSupport~must(book~addPlan(p2),"p2")
req=.AllJapanInsuranceRatingRequest~new("S","PI","GB","GBP","2026-08-28","TURNOVER_MINOR",100,"INDEMNITY_LIMIT_MINOR",100)
r=book~resolve(req)
ignored=.AJITestSupport~assert(\r~ok,"overlapping plans rejected at resolution")
ignored=.AJITestSupport~assert(r~code="RATE_PLAN_AMBIGUOUS","no last-plan-wins pricing")
say "PASS overlapping effective rate plans are ambiguous"
::requires "TestSupport.cls"
