/* test_native_additions.rex -- qualify the two proposed Audio V9 native additions on the dev16 fixture. Coding: Claude (Opus 5.5). */
numeric digits 20
root=value('AUDIO_V9_VOICE_ROOT',,'ENVIRONMENT')
p=.AudioV9SpatialNativeProvider~new(root'/run/native/av9_spatial.bridge.json')
a=root'/run/test/a120.f32'; b=root'/run/test/b120.f32'
r=p~xcorr(a,b,-1200,1200,8,2)
best=-9; bl=0
do i=1 to r['LAGS']~items; if r['SCORES'][i]>best then do; best=r['SCORES'][i]; bl=r['LAGS'][i]; end; end
call check abs(bl-960)<=8, 'xcorr peak at known +120 ms (960 samples): lag='bl 'score='best
r2=p~xcorr(a,b,955,965,1,1); b2=-9; l2=0
do i=1 to r2['LAGS']~items; if r2['SCORES'][i]>b2 then do; b2=r2['SCORES'][i]; l2=r2['LAGS'][i]; end; end
call check abs(l2-960)<=1, 'xcorr fine peak within 1 sample: lag='l2
call check r2['SCORES'][6]>r['SCORES'][1], 'peak exceeds far-lag correlation'
m=p~envelope(a,root'/run/test/env.f32',80,1,0)
call check m=trunc(stream(a,'C','QUERY SIZE')/4/80), 'envelope bin count' m
m2=p~envelope(a,root'/run/test/envd.f32',80,1,51)
call check m2=m, 'detrended envelope same length'
ea=root'/run/test/ea.f32'; eb=root'/run/test/eb.f32'
x=p~envelope(a,ea,80,1,51); x=p~envelope(b,eb,80,1,51)
r3=p~xcorr(ea,eb,-30,30,1,1); b3=-9; l3=0
do i=1 to r3['LAGS']~items; if r3['SCORES'][i]>b3 then do; b3=r3['SCORES'][i]; l3=r3['LAGS'][i]; end; end
call check abs(l3-12)<=1, 'envelope xcorr finds 12 bins (120 ms): lag='l3 'score='format(b3,,3)
say 'PASS test_native_additions checks=6'
exit 0
check: procedure
  use arg ok, label
  if \ok then do; say 'FAIL' label; exit 1; end
  say 'ok' label
  return
::requires 'AudioV9SpatialNativeProvider.cls'
