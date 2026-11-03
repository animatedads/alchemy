numeric digits 30
pi=4*RxCalcArcTan(1,30,'R'); target=50; m=2; k=m*(2*pi*target)**2
mode=.RotatingVibrationMode~new('shaft-bend-x',.MathVector3~new(1,0,0),m,k,10)
if abs(mode~naturalFrequency-target)>.000001 then do; say 'FAIL natural frequency' mode~naturalFrequency; exit 1; end
say 'PHYSICS ROTATING MODE FREQUENCY: OK frequency='mode~naturalFrequency
exit 0
::requires 'RotatingVibration.cls'
::requires 'rxmath' LIBRARY
