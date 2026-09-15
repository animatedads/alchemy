r=.AllJapanInsuranceRationalRate~new(1,2,"half")
ignored=.AJITestSupport~assert(r~apply(1)=1,"0.5 rounds half up")
ignored=.AJITestSupport~assert(r~apply(3)=2,"1.5 rounds half up")
r3=.AllJapanInsuranceRationalRate~new(1,3,"third")
ignored=.AJITestSupport~assert(r3~apply(1)=0,"one third rounds down")
ignored=.AJITestSupport~assert(r3~apply(2)=1,"two thirds rounds up")
say "PASS exact rational component rounding"
::requires "TestSupport.cls"
