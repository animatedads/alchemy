row=.AJIProductTestSupport~multiRow("CAR-ROW",.array~of(.AJIProductTestSupport~exactCondition("VEHICLE_GROUP","G1"),.AJIProductTestSupport~rangeCondition("DRIVER_AGE",18,80)),2,1)
table=.AllJapanInsuranceMultiFactorTable~new("CAR-MULTI/2026A","RISK_PREMIUM",.array~of(row))
plan=.AJIProductTestSupport~simplePlan("CAR-M/2026A","CAR","POLICY","VEHICLE_VALUE","VEHICLE_VALUE",.array~of(table))
facts=.table~new; facts["VEHICLE_GROUP"]="G1"
request=.AllJapanInsuranceRatingRequest~new("S","CAR","GB","GBP","2026-06-01","VEHICLE_VALUE",1000000,"VEHICLE_VALUE",1000000,facts)
r=.AllJapanInsuranceRatingEngine~new~rate("R",request,plan,"2026-06-01T00:00:00")
.AJITestSupport~assert(\r~ok & r~code="FACTOR_FACT_REQUIRED" & r~detail="DRIVER_AGE","missing multidimensional fact fails closed")
say "PASS multidimensional table requires every declared fact"
::requires "TestSupport.cls"
::requires "ProductTestSupport.cls"
