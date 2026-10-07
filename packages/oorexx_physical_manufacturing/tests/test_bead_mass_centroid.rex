call require 'FiniteDeposition.cls'
a=.array~new
a~append(.DepositionPathSample~new(0.01,0.0,0.001))
a~append(.DepositionPathSample~new(0.02,0.010,0.002))
b=.DepositedBead~new('b1',a,.nil,0,0.02)
if abs(b~mass-0.003)>1e-12 then raise syntax 88.900 array('mass conservation')
if abs(b~centroidCoordinate-(0.020/3))>1e-12 then raise syntax 88.900 array('mass weighted centroid')
say 'PHYSICAL MANUFACTURING BEAD MASS CENTROID: OK'
