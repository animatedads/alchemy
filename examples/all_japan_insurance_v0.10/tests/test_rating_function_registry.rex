registry=.AllJapanInsuranceRatingFunctionRegistry~new
f=.AllJapanInsuranceRatingFunctionMinThenProrateV1~new
ignored=.AJITestSupport~must(registry~register(f),"first function")
dup=registry~register(.AllJapanInsuranceRatingFunctionMinThenProrateV1~new)
ignored=.AJITestSupport~assert(\dup~ok,"duplicate function identity rejected")
ignored=.AJITestSupport~assert(dup~code="RATING_FUNCTION_DUPLICATE","duplicate code")

tier=.AllJapanInsuranceTieredRiskPrice~new("BASIS",0,0,.AllJapanInsuranceRationalRate~new(0,1),.AllJapanInsuranceRationalRate~new(0,1))
uw=.AllJapanInsuranceUnderwritingPrice~new("UW",.false,0,0,.AllJapanInsuranceRationalRate~new(0,1))
plan=.AllJapanInsuranceRatingPlan~new("UNKNOWN-FN-PLAN","PI","GB","GBP","2026-01-01","",tier,uw,.AllJapanInsuranceSalesCostRule~new,.array~new,"AJI.RATING.UNKNOWN/99")
book=.AllJapanInsuranceRateBook~new(registry)
r=book~addPlan(plan)
ignored=.AJITestSupport~assert(\r~ok,"unknown executable function blocks publication")
ignored=.AJITestSupport~assert(r~code="RATING_FUNCTION_NOT_FOUND","unknown function code")
say "PASS rating function registry is immutable and publication-gated"
::requires "TestSupport.cls"
