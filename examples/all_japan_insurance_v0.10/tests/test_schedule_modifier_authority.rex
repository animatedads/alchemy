rule=.AllJapanInsuranceScheduleModifierRule~new("IRPM",.AllJapanInsuranceRationalRate~new(8,10),.AllJapanInsuranceRationalRate~new(12,10),.true)
tier=.AllJapanInsuranceTieredRiskPrice~new("BASIS",10000,0,.AllJapanInsuranceRationalRate~new(0,1),.AllJapanInsuranceRationalRate~new(0,1))
uw=.AllJapanInsuranceUnderwritingPrice~new("UW",.false,0,0,.AllJapanInsuranceRationalRate~new(0,1))
plan=.AllJapanInsuranceRatingPlan~new("MOD-PLAN","PI","GB","GBP","2026-01-01","",tier,uw,.AllJapanInsuranceSalesCostRule~new,.array~new,.AllJapanInsuranceRatingBuild~FUNCTION_MIN_THEN_PRORATE,.nil,.array~of(rule))
sel=.AllJapanInsuranceSelectedModifier~new("IRPM",.AllJapanInsuranceRationalRate~new(9,10),"strong risk controls","UW-42")
req=.AllJapanInsuranceRatingRequest~new("S-MOD","PI","GB","GBP","2026-08-28","BASIS",0,"UW",0,.nil,.array~of(sel))
r=.AJITestSupport~must(.AllJapanInsuranceRatingEngine~new~rate("R-MOD",req,plan,"2026-08-28T12:00:00"),"rated modifier")~value
ignored=.AJITestSupport~assert(r~componentAmount("SCHEDULE_MODIFIER")=-1000,"10 percent discount retained as negative adjustment")
ignored=.AJITestSupport~assert(r~riskPremiumMinor=9000,"schedule modifier applied")

bad=.AllJapanInsuranceSelectedModifier~new("IRPM",.AllJapanInsuranceRationalRate~new(7,10),"too much","UW-42")
reqBad=.AllJapanInsuranceRatingRequest~new("S-BAD","PI","GB","GBP","2026-08-28","BASIS",0,"UW",0,.nil,.array~of(bad))
x=.AllJapanInsuranceRatingEngine~new~rate("R-BAD",reqBad,plan,"2026-08-28T12:00:00")
ignored=.AJITestSupport~assert(\x~ok & x~code="MODIFIER_OUTSIDE_AUTHORITY","authority range enforced")

noEvidence=.AllJapanInsuranceSelectedModifier~new("IRPM",.AllJapanInsuranceRationalRate~new(9,10))
reqNo=.AllJapanInsuranceRatingRequest~new("S-NO","PI","GB","GBP","2026-08-28","BASIS",0,"UW",0,.nil,.array~of(noEvidence))
x=.AllJapanInsuranceRatingEngine~new~rate("R-NO",reqNo,plan,"2026-08-28T12:00:00")
ignored=.AJITestSupport~assert(\x~ok & x~code="MODIFIER_EVIDENCE_REQUIRED","non-unity modifier needs authority evidence")
say "PASS schedule modifiers are bounded and evidence-bearing"
::requires "TestSupport.cls"
