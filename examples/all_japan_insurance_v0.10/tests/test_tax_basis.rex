tier=.AllJapanInsuranceTieredRiskPrice~new("EXPOSURE",10000,0,.AllJapanInsuranceRationalRate~new(0,1),.AllJapanInsuranceRationalRate~new(0,1))
uw=.AllJapanInsuranceUnderwritingPrice~new("LIMIT",.false,0,0,.AllJapanInsuranceRationalRate~new(0,1))
sales=.AllJapanInsuranceSalesCostRule~new("ADDITIVE",0,.AllJapanInsuranceRationalRate~new(1,10,"10%"))
taxes=.array~of(.AllJapanInsuranceTaxRule~new("ON_GROSS","PRE_TAX_PREMIUM",.AllJapanInsuranceRationalRate~new(1,10,"10%")),.AllJapanInsuranceTaxRule~new("ON_RISK","RISK_PREMIUM",.AllJapanInsuranceRationalRate~new(1,10,"10%")))
plan=.AllJapanInsuranceRatingPlan~new("P","HOME","GB","GBP","2026-01-01","",tier,uw,sales,taxes)
req=.AllJapanInsuranceRatingRequest~new("S","HOME","GB","GBP","2026-08-28","EXPOSURE",0,"LIMIT",0)
x=.AJITestSupport~must(.AllJapanInsuranceRatingEngine~new~rate("R",req,plan,"2026-08-28"),"rate")~value
ignored=.AJITestSupport~assert(x~componentAmount("TAX_ON_GROSS")=1100,"tax can include sales cost")
ignored=.AJITestSupport~assert(x~componentAmount("TAX_ON_RISK")=1000,"tax can exclude sales cost")
ignored=.AJITestSupport~assert(x~totalPremiumMinor=13100,"taxes do not accidentally tax each other")
say "PASS explicit tax bases avoid hidden tax ordering assumptions"
::requires "TestSupport.cls"
