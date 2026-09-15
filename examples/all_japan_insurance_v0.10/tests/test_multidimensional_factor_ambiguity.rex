rows=.array~new
rows~append(.AJIProductTestSupport~multiRow("ROW-1",.array~of(.AJIProductTestSupport~rangeCondition("DRIVER_AGE",18,30)),2,1))
rows~append(.AJIProductTestSupport~multiRow("ROW-2",.array~of(.AJIProductTestSupport~rangeCondition("DRIVER_AGE",25,40)),3,2))
table=.AllJapanInsuranceMultiFactorTable~new("CAR-AGE-OVERLAP/TEST","RISK_PREMIUM",rows)
plan=.AJIProductTestSupport~simplePlan("CAR-COVER/TEST","CAR","POLICY","VEHICLE_VALUE","VEHICLE_VALUE",.array~of(table))
facts=.table~new; facts["DRIVER_AGE"]=27
request=.AllJapanInsuranceRatingRequest~new("SUB-2","CAR","GB","GBP","2026-05-01","VEHICLE_VALUE",2000000,"VEHICLE_VALUE",2000000,facts)
r=.AllJapanInsuranceRatingEngine~new~rate("RATE-2",request,plan,"2026-05-01T12:00:00")
.AJITestSupport~assert(\r~ok & r~code="FACTOR_ROW_AMBIGUOUS","overlapping multidimensional rows fail closed")
say "PASS multidimensional factor overlap fails closed"
::requires "TestSupport.cls"
::requires "ProductTestSupport.cls"
