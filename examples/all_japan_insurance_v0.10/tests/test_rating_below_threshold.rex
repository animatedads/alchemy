plan=.AJITestSupport~samplePlan
req=.AllJapanInsuranceRatingRequest~new("S-RATE-2","PI","GB","GBP","2026-08-28","TURNOVER_MINOR",5000000,"INDEMNITY_LIMIT_MINOR",50000000)
r=.AJITestSupport~must(.AllJapanInsuranceRatingEngine~new~rate("R-2",req,plan,"2026-08-28T12:00:00"),"rate")
x=r~value
ignored=.AJITestSupport~assert(x~componentAmount("FIXED")=10000,"fixed")
ignored=.AJITestSupport~assert(x~componentAmount("PROPORTIONATE_UP_TO_STEP")=5000,"within step")
ignored=.AJITestSupport~assert(x~componentAmount("PROPORTIONATE_OVER_STEP")=0,"no over step")
ignored=.AJITestSupport~assert(x~componentAmount("UNDERWRITER_FEE")=0,"no UW fee")
ignored=.AJITestSupport~assert(x~componentAmount("OVERAGE")=0,"no overage")
ignored=.AJITestSupport~assert(\x~requiresUnderwriter,"no UW referral flag")
ignored=.AJITestSupport~assert(x~totalPremiumMinor=18480,"below threshold total")
say "PASS below-step and below-underwriting-risk path"
::requires "TestSupport.cls"
