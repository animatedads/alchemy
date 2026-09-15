registry=.AllJapanInsuranceStandardProductDefinitions~registry
rateBook=.AllJapanInsuranceRateBook~new
b=.AJIProductTestSupport~simplePlan("HOME-B/2026A","HOME","BUILDINGS","REBUILD_VALUE","REBUILD_VALUE")
c=.AJIProductTestSupport~simplePlan("HOME-C/2026A","HOME","CONTENTS","CONTENTS_VALUE","CONTENTS_VALUE")
.AJITestSupport~must(rateBook~addPlan(b),"add b")
.AJITestSupport~must(rateBook~addPlan(c),"add c")
book=.AllJapanInsuranceProductRatingBook~new(registry,rateBook)
refs=.table~new; refs["BUILDINGS"]=b~planRef
r=book~addProgram(.AJIProductTestSupport~program("HOME-PROG/BAD","AJI.PRODUCT.HOME/0.5","HOME",refs))
.AJITestSupport~assert(\r~ok & r~code="PRODUCT_COVERAGE_PLAN_NOT_FOUND","all product coverages pinned")
refs["CONTENTS"]=c~planRef
program=.AJIProductTestSupport~program("HOME-PROG/GOOD","AJI.PRODUCT.HOME/0.5","HOME",refs)
.AJITestSupport~must(book~addProgram(program),"good program")
r=book~addProgram(program)
.AJITestSupport~assert(\r~ok & r~code="PRODUCT_RATING_PROGRAM_DUPLICATE","program identity immutable")
say "PASS product rating program pins complete immutable coverage-plan set"
::requires "TestSupport.cls"
::requires "ProductTestSupport.cls"
