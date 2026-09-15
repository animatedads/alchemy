t1=.array~of(0,1,2,4,7,8,11,15)
t2=.array~of(0,1,2,4,7,11,14,18)
v=.array~of(0,1,3,7,10,7,3,1)
s1=.MLTemporalPatternSeries~scalar(t1,v,'BASE')
s2=.MLTemporalPatternSeries~scalar(t2,v,'DELAY')
p=.MLTemporalPatternPolicy~new(24,32,48,72,48,48,1,12,4,10,12,.true,.true,1)
schema=.MLCylindricalTemporalPatternSchema~new(p,'LOCAL-TIME')
d=schema~difference(schema~encode(s1),schema~encode(s2))
call assert \d~exact,'local timing fluctuation must survive global time-scale normalization'
call assert d~timeMax>0 | d~elevationMax>0,'local timing change should appear in time/elevation evidence'
say 'PASS temporal_pattern_local_jitter dominant='d~dominantDelta 'kind='d~dominantKind
exit 0
assert: procedure; use strict arg ok,msg; if \ok then raise syntax 88.900 array(msg); return
::requires "OorexxML.cls"
