numeric digits 30
h=.HarmonicSampleHistory~new
pi=4*RxCalcArcTan(1,30,'R'); f=20; dt=.001; n=1000
do i=0 to n-1
 t=i*dt
 v=3*RxCalcSin(2*pi*f*t,30,'R')+.4*RxCalcSin(2*pi*40*t,30,'R')
 h~append(t,v)
end
a20=h~component(20); a40=h~component(40); a30=h~component(30)
if abs(a20~amplitude-3)>.0001 then do; say 'FAIL 20Hz amplitude' a20~amplitude; exit 1; end
if abs(a40~amplitude-.4)>.0001 then do; say 'FAIL 40Hz amplitude' a40~amplitude; exit 1; end
if a30~amplitude>.0001 then do; say 'FAIL invented 30Hz harmonic' a30~amplitude; exit 1; end
say 'PHYSICS HARMONIC OBSERVATION: OK 20Hz='a20~amplitude '40Hz='a40~amplitude
exit 0
::requires 'RotatingMachinery.cls'
::requires 'rxmath' LIBRARY
