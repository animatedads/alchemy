t=.array~of(0,1,2,4,7,8,11,15)
v=.array~of(0,1,3,7,10,7,3,1)
t2=.array~new; v2=.array~new
n=t~items
do i=1 to n-1
  t2~append(t[i]); v2~append(v[i]); t2~append((t[i]+t[i+1])/2); v2~append((v[i]+v[i+1])/2)
end
t2~append(t[n]); v2~append(v[n])
a=.MLTemporalPatternSeries~scalar(t,v,'SPARSE')
b=.MLTemporalPatternSeries~scalar(t2,v2,'DENSE')
p=.MLTemporalPatternPolicy~new(24,48,48,72,48,48,1,12,5,10,14,.true,.true,1)
schema=.MLCylindricalTemporalPatternSchema~new(p,'DENSITY')
d=schema~difference(schema~encode(a),schema~encode(b))
call assert d~exact,'linearly densified event trace should preserve temporal pattern hash'
say 'PASS temporal_pattern_sample_density'
exit 0
assert: procedure; use strict arg ok,msg; if \ok then raise syntax 88.900 array(msg); return
::requires "OorexxML.cls"
