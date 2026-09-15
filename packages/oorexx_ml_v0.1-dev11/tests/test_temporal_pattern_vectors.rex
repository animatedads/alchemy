t=.array~of(0,1,3,4,7,9)
v=.array~of(0,2,5,9,4,1)
s=.MLTemporalPatternSeries~scalar(t,v,'VECTOR')
p=.MLTemporalPatternPolicy~new(18,24,24,72,36,36,1,8,4,8,10,.true,.true,1)
schema=.MLCylindricalTemporalPatternSchema~new(p,'VECTOR')
h=schema~encode(s)
call assert h~vectors~items=17,'one channel with 18 angular samples should have 17 open cylindrical segments'
call assert h~points~items=18,'one channel should retain one point per angular sample'
do vector over h~vectors
  call assert vector~bearingDegrees>=0 & vector~bearingDegrees<360,'bearing must be a circular angle'
  call assert vector~elevationDegrees>=-90 & vector~elevationDegrees<=90,'elevation must be a vertical angle'
  call assert vector~length>=0,'vector length must be nonnegative'
end
say 'PASS temporal_pattern_vectors'
exit 0
assert: procedure; use strict arg ok,msg; if \ok then raise syntax 88.900 array(msg); return
::requires "OorexxML.cls"
