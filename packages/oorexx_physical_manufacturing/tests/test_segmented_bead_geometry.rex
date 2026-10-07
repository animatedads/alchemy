call require 'SegmentedDeposition.cls'
b=.SegmentedDepositionBuilder~new('bead',0,0)
b~append(0.01,0.010,0.001,0.010)
b~append(0.02,0.015,0.001,0.010)
r=b~finish
if r~elementCount<>2 then raise syntax 88.900 array('element count')
if abs(r~mass-0.002)>1e-12 then raise syntax 88.900 array('mass conservation')
if abs(r~actualPathLength-0.015)>1e-12 then raise syntax 88.900 array('actual path')
if abs(r~nominalPathLength-0.020)>1e-12 then raise syntax 88.900 array('nominal path')
if r~elements[2]~stretchRatio>=1 then raise syntax 88.900 array('second element must expose compression')
say 'PHYSICAL MANUFACTURING SEGMENTED BEAD GEOMETRY: OK'
