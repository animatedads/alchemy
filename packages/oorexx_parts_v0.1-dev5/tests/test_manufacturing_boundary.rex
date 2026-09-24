p=.CommonParts~diode1N4148
if p~geometry['PACKAGE'] <> 'DO-35' then call fail 'package geometry identity'
if p~material('SEMICONDUCTOR') <> 'SI-INTRINSIC-REFERENCE' then call fail 'material role'
if p~manufacturing['PROCESS'] <> 'SEMICONDUCTOR_ASSEMBLY' then call fail 'process identity'
if p~parameter('REVERSE_VOLTAGE_RATING') <> '100 V' then call fail 'rating retained as typed source text'
say 'PARTS MANUFACTURING BOUNDARY: OK'
exit 0
fail: procedure
 parse arg m
 say 'FAIL:' m
 exit 1
::requires 'PartsCatalog.cls'
