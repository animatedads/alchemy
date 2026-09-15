book=.AllJapanInsuranceRateBook~new
b=.AJIProductTestSupport~simplePlan("HOME-B/2026A","HOME","BUILDINGS","VALUE","VALUE")
c=.AJIProductTestSupport~simplePlan("HOME-C/2026A","HOME","CONTENTS","VALUE","VALUE")
.AJITestSupport~must(book~addPlan(b),"add buildings")
.AJITestSupport~must(book~addPlan(c),"add contents")
request=.AllJapanInsuranceRatingRequest~new("S","HOME","GB","GBP","2026-06-01","VALUE",1000000,"VALUE",1000000,.nil,.nil,.nil,"PROPERTY-1","BUILDINGS")
r=book~resolve(request)
.AJITestSupport~must(r,"coverage-specific resolution")
.AJITestSupport~assert(r~value~planRef="HOME-B/2026A","coverage separates same-basis plans")
say "PASS rate-book resolution includes coverage identity"
::requires "TestSupport.cls"
::requires "ProductTestSupport.cls"
