t1=.array~of(0,1,2,4,7,8,11,15)
t2=.array~of(100,102,104,108,114,116,122,130)
v1=.array~of(0,1,3,7,10,7,3,1)
v2=.array~of(100,110,130,170,200,170,130,110)
s1=.MLTemporalPatternSeries~scalar(t1,v1,'A')
s2=.MLTemporalPatternSeries~scalar(t2,v2,'B')
p=.MLTemporalPatternPolicy~new(24,32,32,72,36,36,1,8,4,8,10,.true,.true,1)
schema=.MLCylindricalTemporalPatternSchema~new(p,'TIME-SCALE')
d=schema~difference(schema~encode(s1),schema~encode(s2))
call assert d~exact,'affine value and global time scale should be invariant when requested'
call assert d~dominantKind='NONE','exact difference should have no dominant kind'
p2=.MLTemporalPatternPolicy~new(24,32,32,72,36,36,1,8,4,8,10,.true,.false,1)
schema2=.MLCylindricalTemporalPatternSchema~new(p2,'TIME-ABS')
d2=schema2~difference(schema2~encode(s1),schema2~encode(s2))
call assert \d2~exact,'absolute timing mode must distinguish globally stretched time'
say 'PASS temporal_pattern_time_scale'
exit 0
assert: procedure; use strict arg ok,msg; if \ok then raise syntax 88.900 array(msg); return
::requires "OorexxML.cls"
