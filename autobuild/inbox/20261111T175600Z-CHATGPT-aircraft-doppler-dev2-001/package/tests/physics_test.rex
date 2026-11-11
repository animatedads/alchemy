obj = .AcousticFlyoverPhysics
passed = 0
call check abs(obj~slantRange(3,4,12)-13) < 0.0000001, 'range 3D'
call check abs(obj~rangeRate(100,0,0,-50,0,0)+50) < 0.0000001, 'approaching range rate'
call check abs(obj~arrivalUtc(1000,686)-1002) < 0.0000001, 'retarded arrival'
call check abs(obj~observedFrequency(200,0)-200) < 0.0000001, 'stationary frequency'
call check obj~observedFrequency(200,-50) > 200, 'approach upshift'
call check obj~observedFrequency(200,50) < 200, 'recession downshift'
say 'PASS' passed 'physical assertions'
exit 0
check: procedure expose passed
 use arg value, label
 if \value then do
   say 'FAIL' label
   exit 1
 end
 passed += 1
 return

::requires "src/AcousticFlyoverPhysics.cls"
