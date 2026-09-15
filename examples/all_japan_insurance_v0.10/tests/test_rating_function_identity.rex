tier=.AllJapanInsuranceTieredRiskPrice~new("BASIS",12000,0,.AllJapanInsuranceRationalRate~new(0,1),.AllJapanInsuranceRationalRate~new(0,1))
uw=.AllJapanInsuranceUnderwritingPrice~new("UW",.false,0,0,.AllJapanInsuranceRationalRate~new(0,1))
sales=.AllJapanInsuranceSalesCostRule~new
proration=.AllJapanInsuranceProration~new(1,2,"HALF_TERM")
req=.AllJapanInsuranceRatingRequest~new("S-FN","PI","GB","GBP","2026-08-28","BASIS",0,"UW",0,.nil,.nil,proration)
plan1=.AllJapanInsuranceRatingPlan~new("PLAN-FN-1","PI","GB","GBP","2026-01-01","",tier,uw,sales,.array~new,.AllJapanInsuranceRatingBuild~FUNCTION_MIN_THEN_PRORATE,.nil,.nil,10000)
plan2=.AllJapanInsuranceRatingPlan~new("PLAN-FN-2","PI","GB","GBP","2026-01-01","",tier,uw,sales,.array~new,.AllJapanInsuranceRatingBuild~FUNCTION_PRORATE_THEN_MIN,.nil,.nil,10000)
e=.AllJapanInsuranceRatingEngine~new
r1=.AJITestSupport~must(e~rate("R-FN-1",req,plan1,"2026-08-28T12:00:00"),"min then prorate")~value
r2=.AJITestSupport~must(e~rate("R-FN-2",req,plan2,"2026-08-28T12:00:00"),"prorate then min")~value
ignored=.AJITestSupport~assert(r1~totalPremiumMinor=6000,"full-term minimum then half-term proration")
ignored=.AJITestSupport~assert(r2~totalPremiumMinor=10000,"transaction minimum after proration")
ignored=.AJITestSupport~assert(r1~ratingFunctionRef=.AllJapanInsuranceRatingBuild~FUNCTION_MIN_THEN_PRORATE,"function one retained")
ignored=.AJITestSupport~assert(r2~ratingFunctionRef=.AllJapanInsuranceRatingBuild~FUNCTION_PRORATE_THEN_MIN,"function two retained")
ignored=.AJITestSupport~assert(r1~totalPremiumMinor\=r2~totalPremiumMinor,"same inputs can differ by versioned executable semantics")
say "PASS rating function identity changes executable premium semantics"
::requires "TestSupport.cls"
