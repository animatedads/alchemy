/* dev51: exact inverse on the monotone prefix, fail closed past maximum. */
numeric digits 30
t=.AerodynamicCoefficientTable1D~new(.array~of(-4,0,4,8,12),.array~of(-0.2,0.2,0.6,1.0,0.9))
if t~inverseMonotone(0.4)<>2 | t~inverseMonotone(1.0)<>8 then do; say 'FAIL inverse'; exit 1; end
top=t~monotoneMaximum
if top[1]<>8 | top[2]<>1.0 then do; say 'FAIL monotone maximum'; exit 1; end
if t~evaluate(t~inverseMonotone(0.73))<>0.73 then do; say 'FAIL round trip'; exit 1; end
signal on syntax name ok
x=t~inverseMonotone(1.05)
say 'FAIL inverse past CLmax accepted'; exit 1
ok:
say 'PHYSICS AERO TABLE INVERSE: OK'
::requires 'AerodynamicCoefficientTables.cls'
