/* Pure structural gate: the element process must retain one mechanical/thermal section per path element. */
text=charin('rexx/ElementDeposition.cls',1,chars('rexx/ElementDeposition.cls'))
if pos('do e over bead~elements',text)=0 then raise syntax 88.900 array('element commit loop absent')
if pos('_thermalProcess~depositSection',text)=0 then raise syntax 88.900 array('element physical commit absent')
if pos('massWeightedCoordinate',text)>0 then raise syntax 88.900 array('centroid reduction leaked into dev8 process')
say 'PHYSICAL MANUFACTURING ELEMENT RESOLVED COMMIT: OK'

::requires 'ElementDeposition.cls'
