registry=.AllJapanInsuranceStandardProductDefinitions~registry
rateBook=.AllJapanInsuranceRateBook~new
b=.AJIProductTestSupport~simplePlan("AJI-HOME-BUILDINGS/2026A","HOME","BUILDINGS","REBUILD_VALUE","REBUILD_VALUE")
c=.AJIProductTestSupport~simplePlan("AJI-HOME-CONTENTS/2026A","HOME","CONTENTS","CONTENTS_VALUE","CONTENTS_VALUE")
.AJITestSupport~must(rateBook~addPlan(b),"add buildings")
.AJITestSupport~must(rateBook~addPlan(c),"add contents")
refs=.table~new; refs["BUILDINGS"]=b~planRef; refs["CONTENTS"]=c~planRef
book=.AllJapanInsuranceProductRatingBook~new(registry,rateBook)
.AJITestSupport~must(book~addProgram(.AJIProductTestSupport~program("AJI.PROGRAM.HOME/2026A","AJI.PRODUCT.HOME/0.5","HOME",refs)),"add home program")
facts=.table~new; facts["CONSTRUCTION_CLASS"]="STANDARD"; facts["POSTCODE_ZONE"]="Z1"; facts["OCCUPANCY_CLASS"]="OWNER"; facts["SECURITY_CLASS"]="A"; facts["REBUILD_VALUE"]=10000000; facts["CONTENTS_VALUE"]=2000000
covers=.array~of(.AllJapanInsuranceCoverageSelection~new("BUILDINGS"),.AllJapanInsuranceCoverageSelection~new("CONTENTS"))
risk=.AllJapanInsuranceRiskObject~new("PROPERTY-1","HOME","PROPERTY",facts,covers)
r=book~rate("PORT-RATE-HOME-1","SUB-HOME-1","HOME","GB","GBP","2026-05-01",.array~of(risk),"2026-05-01T12:00:00")
.AJITestSupport~must(r,"home product rating")
rating=r~value
.AJITestSupport~assert(rating~scopeAmount("PROPERTY-1","BUILDINGS")=11000,"buildings amount")
.AJITestSupport~assert(rating~scopeAmount("PROPERTY-1","CONTENTS")=3000,"contents amount")
.AJITestSupport~assert(rating~totalPremiumMinor=14000,"home aggregate")
.AJITestSupport~assert(rating~subRatings~items=2,"two subratings")
say "PASS Home rating aggregates separate building and contents coverages"
::requires "TestSupport.cls"
::requires "ProductTestSupport.cls"
