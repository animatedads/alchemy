numeric digits 50
r=.RexxTronicsPartFactory~instantiate(.CommonParts~resistor('1 kohm','1','0.25 W'),'R1')
if abs(r~resistance~in(.Units~ohm)-1000) > 0.0000001 then call fail 'resistance'
if abs(r~tolerance~in(.Units~percent)-1) > 0.0000001 then call fail 'tolerance'
d=.RexxTronicsPartFactory~instantiate(.CommonParts~diode1N4148,'D1')
if abs(d~forwardVoltage~in(.Units~volt)-0.7) > 0.0000001 then call fail 'diode forward model'
led=.RexxTronicsPartFactory~instantiate(.CommonParts~ledRed5mm,'LED1')
if abs(led~wavelength~in(.Units~nanometre)-625) > 0.000001 then call fail 'LED wavelength'
say 'PARTS REXX-TRONICS FACTORY: OK'
exit 0
fail: procedure
 parse arg m
 say 'FAIL:' m
 exit 1
::requires 'PartsCatalog.cls'
