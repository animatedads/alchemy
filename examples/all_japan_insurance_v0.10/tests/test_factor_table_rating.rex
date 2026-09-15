rows=.table~new
rows["A"]=.AllJapanInsuranceRationalRate~new(8,10,"class A 0.8")
rows["B"]=.AllJapanInsuranceRationalRate~new(12,10,"class B 1.2")
factorTable=.AllJapanInsuranceFactorTable~new("AJI-FACTOR-PROFESSION/2026A","PROFESSION_CLASS","PROPORTIONATE",rows)
tier=.AllJapanInsuranceTieredRiskPrice~new("TURNOVER",1000,10000,.AllJapanInsuranceRationalRate~new(1,1),.AllJapanInsuranceRationalRate~new(1,1))
uw=.AllJapanInsuranceUnderwritingPrice~new("UW",.false,0,0,.AllJapanInsuranceRationalRate~new(0,1))
plan=.AllJapanInsuranceRatingPlan~new("FACTOR-PLAN","PI","GB","GBP","2026-01-01","",tier,uw,.AllJapanInsuranceSalesCostRule~new,.array~new,.AllJapanInsuranceRatingBuild~FUNCTION_MIN_THEN_PRORATE,.array~of(factorTable))
facts=.table~new
facts["PROFESSION_CLASS"]="B"
req=.AllJapanInsuranceRatingRequest~new("S-FAC","PI","GB","GBP","2026-08-28","TURNOVER",10000,"UW",0,facts)
r=.AJITestSupport~must(.AllJapanInsuranceRatingEngine~new~rate("R-FAC",req,plan,"2026-08-28T12:00:00"),"rate factor")~value
ignored=.AJITestSupport~assert(r~componentAmount("FIXED")=1000,"fixed retained")
ignored=.AJITestSupport~assert(r~componentAmount("PROPORTIONATE_UP_TO_STEP")=10000,"raw proportionate retained")
ignored=.AJITestSupport~assert(r~componentAmount("RATE_FACTOR_ADJUSTMENT")=2000,"factor delta retained")
ignored=.AJITestSupport~assert(r~riskPremiumMinor=13000,"factor applies to proportional element only")
found=.false
do c over r~costs
  if c~code="RATE_FACTOR_ADJUSTMENT" then do
    ignored=.AJITestSupport~assert(c~ruleRef="AJI-FACTOR-PROFESSION/2026A","table release retained as evidence")
    found=.true
  end
end
ignored=.AJITestSupport~assert(found,"factor cost exists")
say "PASS versioned factor table adjusts selected rating target with evidence"
::requires "TestSupport.cls"
