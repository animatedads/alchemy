call require 'SegmentedDeposition.cls'
b=.SegmentedDepositionBuilder~new('reversal',0,0)
b~append(0.01,0.010,0.001,0.010)
b~append(0.02,0.020,0.001,0.010)
b~append(0.03,0.015,0.001,0.010)
r=b~finish
if r~reversalCount<>1 then raise syntax 88.900 array('physical path reversal must be retained')
if r~elements[3]~direction<>-1 then raise syntax 88.900 array('reverse element direction')
say 'PHYSICAL MANUFACTURING SEGMENTED BEAD REVERSAL: OK'
