plan=.AJITestSupport~samplePlan
req=.AllJapanInsuranceRatingRequest~new("S-RATE-1","PI","GB","GBP","2026-08-28","TURNOVER_MINOR",15000000,"INDEMNITY_LIMIT_MINOR",150000000)
engine=.AllJapanInsuranceRatingEngine~new
r=.AJITestSupport~must(engine~rate("R-1",req,plan,"2026-08-28T12:00:00"),"rate")
x=r~value
ignored=.AJITestSupport~assert(x~componentAmount("FIXED")=10000,"fixed element")
ignored=.AJITestSupport~assert(x~componentAmount("PROPORTIONATE_UP_TO_STEP")=10000,"proportionate to step")
ignored=.AJITestSupport~assert(x~componentAmount("PROPORTIONATE_OVER_STEP")=10000,"proportionate over step")
ignored=.AJITestSupport~assert(x~componentAmount("UNDERWRITER_FEE")=5000,"underwriter fee")
ignored=.AJITestSupport~assert(x~componentAmount("OVERAGE")=5000,"overage")
ignored=.AJITestSupport~assert(x~componentAmount("COMMISSION_OR_SALES_COST")=4000,"commission sales cost")
ignored=.AJITestSupport~assert(x~componentAmount("TAX_IPT_TEST")=5280,"tax last")
ignored=.AJITestSupport~assert(x~riskPremiumMinor=40000,"risk premium subtotal")
ignored=.AJITestSupport~assert(x~preTaxPremiumMinor=44000,"pre tax subtotal")
ignored=.AJITestSupport~assert(x~totalPremiumMinor=49280,"quotation total")
ignored=.AJITestSupport~assert(x~requiresUnderwriter,"underwriter required over authority risk")
ignored=.AJITestSupport~assert(x~underwritingOverageUnits=50000000,"overage basis retained")
ignored=.AJITestSupport~assert(x~balanced,"cost trace balances")
say "PASS quotation formula fixed + stepped proportions + UW fee + overage + sales + tax"
::requires "TestSupport.cls"
