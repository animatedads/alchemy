numeric digits 50
r=.CommonParts~resistor('4.7 kohm')
x=.RexxTronicsPartFactory~instantiate(r,'R1')
if abs(x~resistance~in(.Units~ohm)-4700) > 0.000001 then call fail 'engineering prefix conversion'
c=.CommonParts~capacitor('100 nF')
y=.RexxTronicsPartFactory~instantiate(c,'C1')
if abs(y~capacitance~in(.Units~farad)-0.0000001) > 0.000000000001 then call fail 'capacitance conversion'
say 'PARTS UNITS SANITY: OK'
exit 0
fail: procedure
 parse arg m
 say 'FAIL:' m
 exit 1
::requires 'PartsCatalog.cls'
