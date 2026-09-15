registry=.AllJapanInsuranceStandardProductDefinitions~registry
.AJITestSupport~assert(registry~count=3,"three product definitions")
pi=registry~definition("AJI.PRODUCT.PI/0.5")
facts=.table~new; facts["PROFESSION_CLASS"]="A"; facts["ANNUAL_TURNOVER"]=1000000; facts["TERRITORY"]="GB"; facts["CLAIMS_BAND"]="NONE"
risk=.AllJapanInsuranceRiskObject~new("PRACTICE-1","PI","PROFESSIONAL_PRACTICE",facts,.array~of(.AllJapanInsuranceCoverageSelection~new("PROFESSIONAL_INDEMNITY")))
r=pi~validateRisk(risk)
.AJITestSupport~assert(\r~ok & r~code="PRODUCT_RISK_FACT_REQUIRED","missing indemnity limit rejected")
facts["INDEMNITY_LIMIT"]=5000000
risk=.AllJapanInsuranceRiskObject~new("PRACTICE-1","PI","PROFESSIONAL_PRACTICE",facts,.array~of(.AllJapanInsuranceCoverageSelection~new("BUILDINGS")))
r=pi~validateRisk(risk)
.AJITestSupport~assert(\r~ok & r~code="PRODUCT_COVERAGE_NOT_ALLOWED","cross-product coverage rejected")
say "PASS PI/Home/Car product schemas enforce risk and coverage facts"
::requires "TestSupport.cls"
