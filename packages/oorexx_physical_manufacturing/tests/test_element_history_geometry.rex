b=.SegmentedDepositionBuilder~new('hist',0,0)
b~append(.01,.010,.001,.010,500)
b~append(.02,.015,.001,.010,470)
b~append(.03,.012,.001,.010,440)
r=b~finish
if r~elementCount<>3 then raise syntax 88.900 array('history element count')
if r~reversalCount<>1 then raise syntax 88.900 array('history reversal lost')
if r~elements[1]~temperatureKelvin<>500 then raise syntax 88.900 array('local thermal history lost')
if r~elements[3]~mass<>.001 then raise syntax 88.900 array('local mass history lost')
say 'PHYSICAL MANUFACTURING ELEMENT HISTORY GEOMETRY: OK'

::requires 'SegmentedDeposition.cls'
