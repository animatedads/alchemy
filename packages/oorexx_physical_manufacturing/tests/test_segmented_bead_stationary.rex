call require 'SegmentedDeposition.cls'
b=.SegmentedDepositionBuilder~new('stationary',0,0.1)
e=b~append(0.01,0.1,0.002,0.01)
if e~actualLength<>0 then raise syntax 88.900 array('stationary actual path')
if e~lineDensity<>.nil then raise syntax 88.900 array('zero-length deposition must not invent finite line density')
say 'PHYSICAL MANUFACTURING STATIONARY DEPOSITION: OK'
