rows=.table~new
rows["A"]=.AllJapanInsuranceRationalRate~new(1,1)
t=.AllJapanInsuranceFactorTable~new("TABLE-1","CLASS","PROPORTIONATE",rows)
tier=.AllJapanInsuranceTieredRiskPrice~new("BASIS",0,100,.AllJapanInsuranceRationalRate~new(1,1),.AllJapanInsuranceRationalRate~new(1,1))
uw=.AllJapanInsuranceUnderwritingPrice~new("UW",.false,0,0,.AllJapanInsuranceRationalRate~new(0,1))
plan=.AllJapanInsuranceRatingPlan~new("P","PI","GB","GBP","2026-01-01","",tier,uw,.AllJapanInsuranceSalesCostRule~new,.array~new,.AllJapanInsuranceRatingBuild~FUNCTION_MIN_THEN_PRORATE,.array~of(t))
reqMissing=.AllJapanInsuranceRatingRequest~new("S1","PI","GB","GBP","2026-08-28","BASIS",10,"UW",0)
r=.AllJapanInsuranceRatingEngine~new~rate("R1",reqMissing,plan,"2026-08-28T12:00:00")
ignored=.AJITestSupport~assert(\r~ok & r~code="FACTOR_FACT_REQUIRED","missing fact fails closed")
facts=.table~new; facts["CLASS"]="B"
reqRow=.AllJapanInsuranceRatingRequest~new("S2","PI","GB","GBP","2026-08-28","BASIS",10,"UW",0,facts)
r=.AllJapanInsuranceRatingEngine~new~rate("R2",reqRow,plan,"2026-08-28T12:00:00")
ignored=.AJITestSupport~assert(\r~ok & r~code="FACTOR_ROW_NOT_FOUND","unknown row fails closed")
say "PASS factor-table gaps fail closed rather than silently defaulting"
::requires "TestSupport.cls"
