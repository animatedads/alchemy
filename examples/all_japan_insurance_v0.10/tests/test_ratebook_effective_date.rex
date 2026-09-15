book=.AllJapanInsuranceRateBook~new
old=.AJITestSupport~samplePlan("AJI-RATE-PI-GB-2026A","2026-01-01","2026-07-01")
new=.AJITestSupport~samplePlan("AJI-RATE-PI-GB-2026B","2026-07-01","")
ignored=.AJITestSupport~must(book~addPlan(old),"old plan")
ignored=.AJITestSupport~must(book~addPlan(new),"new plan")
req=.AllJapanInsuranceRatingRequest~new("S-RATE-3","PI","GB","GBP","2026-08-28","TURNOVER_MINOR",100,"INDEMNITY_LIMIT_MINOR",100)
r=.AJITestSupport~must(book~resolve(req),"resolve")
ignored=.AJITestSupport~assert(r~value~planRef="AJI-RATE-PI-GB-2026B","effective-dated plan selected")
say "PASS effective-dated rate-book resolution"
::requires "TestSupport.cls"
