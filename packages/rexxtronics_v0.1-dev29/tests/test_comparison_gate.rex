/* Qualification test for comparison provenance gate. */
a=.RexxTronicsComparisonSample~new(12,'V','RMS','pluck:E2','0-500ms','solver-A','meter-1')
b=.RexxTronicsComparisonSample~new(11,'V','RMS','pluck:E2','0-500ms','solver-A','meter-1')
gate=.RexxTronicsComparisonGate~new
if \gate~compatible(a,b) then raise syntax 93.900 array('matching experimental coordinates rejected')
c=.RexxTronicsComparisonSample~new(11,'A','RMS','pluck:E2','0-500ms','solver-A','meter-1')
if gate~compatible(a,c) then raise syntax 93.900 array('incompatible dimension accepted')
d=.RexxTronicsComparisonSample~new(11,'V','RMS','pluck:E2','0-600ms','solver-A','meter-1')
if gate~compatible(a,d) then raise syntax 93.900 array('incompatible window accepted')
e=.RexxTronicsComparisonSample~new(11,'V','RMS','pluck:E2','0-500ms','solver-B','meter-1')
if gate~compatible(a,e) then raise syntax 93.900 array('incompatible solver accepted')
say 'PASS Rexx-tronics comparison provenance gate'
::requires 'RexxTronicsComparisonGate.cls'
