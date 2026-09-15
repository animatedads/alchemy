rows=.array~new
rows~append(.AJIProductTestSupport~multiRow("PI-A-SMALL-GB",.array~of(.AJIProductTestSupport~exactCondition("PROFESSION_CLASS","A"),.AJIProductTestSupport~rangeCondition("ANNUAL_TURNOVER",0,2000000),.AJIProductTestSupport~exactCondition("TERRITORY","GB")),3,2))
rows~append(.AJIProductTestSupport~multiRow("PI-A-LARGE-GB",.array~of(.AJIProductTestSupport~exactCondition("PROFESSION_CLASS","A"),.AJIProductTestSupport~rangeCondition("ANNUAL_TURNOVER",2000000,10000000),.AJIProductTestSupport~exactCondition("TERRITORY","GB")),2,1))
table=.AllJapanInsuranceMultiFactorTable~new("AJI-PI-MULTI/2026A","RISK_PREMIUM",rows)
plan=.AJIProductTestSupport~simplePlan("PI-COVER/2026A","PI","POLICY","ANNUAL_TURNOVER","INDEMNITY_LIMIT",.array~of(table))
facts=.table~new; facts["PROFESSION_CLASS"]="A"; facts["ANNUAL_TURNOVER"]=1000000; facts["TERRITORY"]="GB"
request=.AllJapanInsuranceRatingRequest~new("SUB-1","PI","GB","GBP","2026-05-01","ANNUAL_TURNOVER",1000000,"INDEMNITY_LIMIT",5000000,facts)
r=.AllJapanInsuranceRatingEngine~new~rate("RATE-1",request,plan,"2026-05-01T12:00:00")
.AJITestSupport~must(r,"multi-dimensional rating")
.AJITestSupport~assert(r~value~totalPremiumMinor=3000,"multi factor total")
.AJITestSupport~assert(r~value~componentAmount("RATE_FACTOR_ADJUSTMENT")=1000,"multi factor adjustment")
say "PASS multidimensional exact/band factor row executes deterministically"
::requires "TestSupport.cls"
::requires "ProductTestSupport.cls"
