numeric digits 30
pi=4*RxCalcArcTan(1,30,'R'); target=20; m=1; k=(2*pi*target)**2
mode=.RotatingVibrationMode~new('shaft',.MathVector3~new(1,0,0),m,k,8)
exp=.RotorVibrationExperiment~new(mode); dt=.0005; maxq=0
do i=0 to 1999
 t=i*dt; f=RxCalcSin(2*pi*target*t,30,'R')
 q=exp~step(dt,.MathVector3~new(f,0,0))
 if abs(q)>maxq then maxq=abs(q)
end
if maxq<.0001 then do; say 'FAIL resonance response too small' maxq; exit 1; end
say 'PHYSICS ROTOR RESONANCE RESPONSE: OK max='maxq
exit 0
::requires 'RotatingVibration.cls'
::requires 'rxmath' LIBRARY
