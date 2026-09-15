registry=.AllJapanInsuranceStandardProductDefinitions~registry
rateBook=.AllJapanInsuranceRateBook~new
plan=.AJIProductTestSupport~simplePlan("AJI-CAR-MOTOR/2026A","CAR","MOTOR","VEHICLE_VALUE","VEHICLE_VALUE")
.AJITestSupport~must(rateBook~addPlan(plan),"add motor plan")
refs=.table~new; refs["MOTOR"]=plan~planRef
book=.AllJapanInsuranceProductRatingBook~new(registry,rateBook)
.AJITestSupport~must(book~addProgram(.AJIProductTestSupport~program("AJI.PROGRAM.CAR/2026A","AJI.PRODUCT.CAR/0.5","CAR",refs)),"add car program")
risks=.array~new
do i=1 to 2
  facts=.table~new; facts["VEHICLE_GROUP"]="G" || i; facts["DRIVER_AGE"]=40; facts["USAGE_CLASS"]="SDP"; facts["POSTCODE_ZONE"]="Z1"; facts["NCD_YEARS"]=5; facts["CLAIMS_BAND"]="NONE"; facts["COVER_LEVEL"]="COMP"; if i=1 then facts["VEHICLE_VALUE"]=3000000; else facts["VEHICLE_VALUE"]=2000000
  risks~append(.AllJapanInsuranceRiskObject~new("VEHICLE-" || i,"CAR","VEHICLE",facts,.array~of(.AllJapanInsuranceCoverageSelection~new("MOTOR"))))
end
r=book~rate("PORT-RATE-CAR-1","SUB-CAR-1","CAR","GB","GBP","2026-05-01",risks,"2026-05-01T12:00:00")
.AJITestSupport~must(r,"car product rating")
.AJITestSupport~assert(r~value~scopeAmount("VEHICLE-1","MOTOR")=4000,"vehicle 1")
.AJITestSupport~assert(r~value~scopeAmount("VEHICLE-2","MOTOR")=3000,"vehicle 2")
.AJITestSupport~assert(r~value~totalPremiumMinor=7000,"car aggregate")
say "PASS Car rating supports multiple insured vehicle risk objects"
::requires "TestSupport.cls"
::requires "ProductTestSupport.cls"
