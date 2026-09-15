non=.array~of("FIXED")
pp=.AllJapanInsuranceProrationPolicy~new(non)
tier=.AllJapanInsuranceTieredRiskPrice~new("BASIS",10000,10000,.AllJapanInsuranceRationalRate~new(1,1),.AllJapanInsuranceRationalRate~new(1,1))
uw=.AllJapanInsuranceUnderwritingPrice~new("UW",.false,0,0,.AllJapanInsuranceRationalRate~new(0,1))
plan=.AllJapanInsuranceRatingPlan~new("PRO-PLAN","CAR","GB","GBP","2026-01-01","",tier,uw,.AllJapanInsuranceSalesCostRule~new,.array~new,.AllJapanInsuranceRatingBuild~FUNCTION_MIN_THEN_PRORATE,.nil,.nil,0,pp)
pro=.AllJapanInsuranceProration~new(1,2,"MID_TERM_1_OF_2")
req=.AllJapanInsuranceRatingRequest~new("S-PRO","CAR","GB","GBP","2026-08-28","BASIS",10000,"UW",0,.nil,.nil,pro)
r=.AJITestSupport~must(.AllJapanInsuranceRatingEngine~new~rate("R-PRO",req,plan,"2026-08-28T12:00:00"),"prorate")~value
ignored=.AJITestSupport~assert(r~fullTermRiskPremiumMinor=20000,"full-term premium retained")
ignored=.AJITestSupport~assert(r~componentAmount("PRORATION_ADJUSTMENT")=-5000,"only proportionate cost is halved")
ignored=.AJITestSupport~assert(r~riskPremiumMinor=15000,"fixed line can be non-proratable")
ignored=.AJITestSupport~assert(r~proration~basisRef="MID_TERM_1_OF_2","proration evidence retained")
say "PASS transaction proration is explicit and cost-code aware"
::requires "TestSupport.cls"
