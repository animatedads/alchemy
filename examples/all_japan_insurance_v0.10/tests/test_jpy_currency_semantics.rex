.AJITestSupport~assert(.AllJapanInsuranceBuild~FUNCTIONAL_CURRENCY="JPY","AJI functional currency")
.AJITestSupport~assert(.AllJapanInsuranceCurrency~minorUnitDigits("JPY")=0,"JPY exponent is zero")
.AJITestSupport~assert(.AllJapanInsuranceCurrency~denominator("JPY")=1,"JPY atomic minor unit is one yen")
.AJITestSupport~assert(.AllJapanInsuranceCurrency~minorUnitDigits("GBP")=2,"GBP minor-unit exponent retained")
.AJITestSupport~assert(.AllJapanInsuranceCurrency~validateMinorAmount("JPY",125001)~ok,"whole yen amount accepted")
.AJITestSupport~assert(\.AllJapanInsuranceCurrency~validateMinorAmount("JPY",125001.5)~ok,"fractional minor unit rejected")
plan=.AJIAccountingTestSupport~jpyPlan
req=.AllJapanInsuranceRatingRequest~new("S-JPY-CURRENCY","HOME","JP","JPY","2026-08-28","REBUILD_VALUE",1000,"REBUILD_VALUE",1000)
r=.AllJapanInsuranceRatingEngine~new~rate("R-JPY-CURRENCY",req,plan,"2026-08-28T10:00:00")
.AJITestSupport~must(r,"JPY rating")
do cost over r~value~costs
  .AJITestSupport~assert(cost~currency="JPY","every rated cost carries JPY")
end
say "PASS JPY is one-yen minor unit and every rated cost carries currency"
::requires "AccountingTestSupport.cls"
