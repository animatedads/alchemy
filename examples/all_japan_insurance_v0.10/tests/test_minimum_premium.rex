tier=.AllJapanInsuranceTieredRiskPrice~new("BASIS",5000,0,.AllJapanInsuranceRationalRate~new(0,1),.AllJapanInsuranceRationalRate~new(0,1))
uw=.AllJapanInsuranceUnderwritingPrice~new("UW",.false,0,0,.AllJapanInsuranceRationalRate~new(0,1))
plan=.AllJapanInsuranceRatingPlan~new("MIN-PLAN","HOME","JP","JPY","2026-01-01","",tier,uw,.AllJapanInsuranceSalesCostRule~new,.array~new,.AllJapanInsuranceRatingBuild~FUNCTION_MIN_THEN_PRORATE,.nil,.nil,10000)
req=.AllJapanInsuranceRatingRequest~new("S-MIN","HOME","JP","JPY","2026-08-28","BASIS",0,"UW",0)
r=.AJITestSupport~must(.AllJapanInsuranceRatingEngine~new~rate("R-MIN",req,plan,"2026-08-28T12:00:00"),"minimum")~value
ignored=.AJITestSupport~assert(r~componentAmount("MINIMUM_PREMIUM_ADJUSTMENT")=5000,"floor adjustment visible")
ignored=.AJITestSupport~assert(r~riskPremiumMinor=10000,"minimum premium floor")
ignored=.AJITestSupport~assert(r~balanced,"minimum cost trace balances")
say "PASS minimum premium is an explicit rated cost rather than a hidden clamp"
::requires "TestSupport.cls"
