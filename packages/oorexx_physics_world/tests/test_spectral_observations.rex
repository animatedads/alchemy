numeric digits 30
h=.SampledScalarHistory~new
pi=4*RxCalcArcTan(1,30,'R')
do i=0 to 999
 t=i*.001
 h~append(t,3*RxCalcSin(2*pi*20*t,30,'R')+.4*RxCalcSin(2*pi*40*t,30,'R'))
end
a=h~component(20); b=h~component(40); z=h~component(30)
if abs(a~amplitude-3)>.0001 | abs(b~amplitude-.4)>.0001 | z~amplitude>.0001 then do; say 'FAIL spectral components'; exit 1; end
say 'PHYSICS GENERAL SPECTRAL OBSERVATION: OK 20Hz='a~amplitude '40Hz=' b~amplitude
exit 0
::requires 'SpectralObservations.cls'
::requires 'rxmath' LIBRARY
