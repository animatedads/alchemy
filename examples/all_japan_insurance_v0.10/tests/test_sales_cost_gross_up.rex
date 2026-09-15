rate=.AllJapanInsuranceRationalRate~new(1,5,"20% of gross")
rule=.AllJapanInsuranceSalesCostRule~new("GROSS_UP",0,rate)
ignored=.AJITestSupport~assert(rule~amount(10000)=2500,"20 percent gross commission needs 25 percent uplift")
add=.AllJapanInsuranceSalesCostRule~new("ADDITIVE",0,rate)
ignored=.AJITestSupport~assert(add~amount(10000)=2000,"additive sales loading remains distinct")
say "PASS commission gross-up and additive sales loading are distinct"
::requires "TestSupport.cls"
