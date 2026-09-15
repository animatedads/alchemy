registry=.AllJapanInsuranceStandardProductDefinitions~registry
rows=.array~of(.AJIProductTestSupport~multiRow("PI-A-SMALL-GB",.array~of(.AJIProductTestSupport~exactCondition("PROFESSION_CLASS","A"),.AJIProductTestSupport~rangeCondition("ANNUAL_TURNOVER",0,2000000),.AJIProductTestSupport~exactCondition("TERRITORY","GB")),3,2))
table=.AllJapanInsuranceMultiFactorTable~new("AJI-PI-RISK-CLASS/2026A","RISK_PREMIUM",rows)
rateBook=.AllJapanInsuranceRateBook~new
plan=.AJIProductTestSupport~simplePlan("AJI-PI-PROF-INDEM/2026A","PI","PROFESSIONAL_INDEMNITY","ANNUAL_TURNOVER","INDEMNITY_LIMIT",.array~of(table))
.AJITestSupport~must(rateBook~addPlan(plan),"add PI coverage plan")
refs=.table~new; refs["PROFESSIONAL_INDEMNITY"]=plan~planRef
book=.AllJapanInsuranceProductRatingBook~new(registry,rateBook)
program=.AJIProductTestSupport~program("AJI.PROGRAM.PI/2026A","AJI.PRODUCT.PI/0.5","PI",refs)
.AJITestSupport~must(book~addProgram(program),"add PI program")
facts=.table~new; facts["PROFESSION_CLASS"]="A"; facts["ANNUAL_TURNOVER"]=1000000; facts["TERRITORY"]="GB"; facts["CLAIMS_BAND"]="NONE"; facts["INDEMNITY_LIMIT"]=5000000
risk=.AllJapanInsuranceRiskObject~new("PRACTICE-1","PI","PROFESSIONAL_PRACTICE",facts,.array~of(.AllJapanInsuranceCoverageSelection~new("PROFESSIONAL_INDEMNITY")))
r=book~rate("PORT-RATE-PI-1","SUB-PI-1","PI","GB","GBP","2026-05-01",.array~of(risk),"2026-05-01T12:00:00")
.AJITestSupport~must(r,"PI product rating")
rating=r~value
.AJITestSupport~assert(rating~planRef="AJI.PROGRAM.PI/2026A","program identity retained")
.AJITestSupport~assert(rating~ratingFunctionRef="AJI.PRODUCT.RATING.COMPOSITE/1","composite function retained")
.AJITestSupport~assert(rating~totalPremiumMinor=3000,"PI premium")
.AJITestSupport~assert(rating~scopeAmount("PRACTICE-1","PROFESSIONAL_INDEMNITY")=3000,"PI scoped premium")
say "PASS PI product rating retains policy-risk-coverage evidence"
::requires "TestSupport.cls"
::requires "ProductTestSupport.cls"
