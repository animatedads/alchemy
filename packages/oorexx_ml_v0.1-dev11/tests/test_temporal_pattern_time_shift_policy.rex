t1=.array~of(0,1,2,4,7,8,11,15)
t2=.array~of(100,101,102,104,107,108,111,115)
v=.array~of(0,1,3,7,10,7,3,1)
a=.MLTemporalPatternSeries~scalar(t1,v,'A'); b=.MLTemporalPatternSeries~scalar(t2,v,'B')
p=.MLTemporalPatternPolicy~new(24,32,32,72,36,36,1,8,4,8,10,.true,.false,1)
s=.MLCylindricalTemporalPatternSchema~new(p,'SHIFT-YES')
call assert s~difference(s~encode(a),s~encode(b))~exact,'time-shift invariant absolute-gap mode should ignore start time'
p2=.MLTemporalPatternPolicy~new(24,32,32,72,36,36,1,8,4,8,10,.false,.false,1)
s2=.MLCylindricalTemporalPatternSchema~new(p2,'SHIFT-NO')
call assert \s2~difference(s2~encode(a),s2~encode(b))~exact,'absolute-time mode should retain start-time displacement'
failed=.false
signal on syntax name bad
ignored=.MLTemporalPatternPolicy~new(24,32,32,72,36,36,1,8,4,8,10,.false,.true,1)
signal off syntax
call assert .false,'time-scale invariance without time-shift invariance must fail closed'
bad:
  failed=.true
  signal off syntax
call assert failed,'invalid policy must raise'
say 'PASS temporal_pattern_time_shift_policy'
exit 0
assert: procedure; use strict arg ok,msg; if \ok then raise syntax 88.900 array(msg); return
::requires "OorexxML.cls"
