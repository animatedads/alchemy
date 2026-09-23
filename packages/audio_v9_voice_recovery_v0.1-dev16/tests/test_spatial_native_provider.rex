numeric digits 30
root=value('AUDIO_V9_VOICE_ROOT',,'ENVIRONMENT')
if root='' then root='.'
provider=.AudioV9SpatialNativeProvider~new(root||'/run/native/av9_spatial.bridge.json')
a=root||'/run/test/a120.f32'; b=root||'/run/test/b120.f32'
m=provider~measure(a,b,8000,500,25)
call assert abs(m~envelopeLagMs-120)<=10,'coarse envelope finds 120ms delayed B'
call assert abs(m~refinedLagMs-120)<=2,'refined waveform finds 120ms delayed B'
call assert m~refinedScore>0.8,'refined correlation strong'
call assert m~refinedCoherence>0.5,'refined local coherence strong'
scan=provider~scan(a,b,8000,8000,4000,500,25)
call assert scan~size=2,'12 second fixture gives two 8s/4s windows'
do row over scan~rows
  call assert abs(row~measurement~refinedLagMs-120)<=2,'scan preserves known delay'
end
out=root||'/run/test/mix.f32'
provider~renderAlignedMix(a,b,out,m~refinedLagSamples,0.5,0.5)
call assert stream(out,'C','QUERY SIZE')>0,'aligned mix rendered'
say 'PASS test_spatial_native_provider assertions=7'
exit 0
assert: procedure
  use strict arg condition,label
  if \condition then do; say 'FAIL' label; exit 1; end
return
::requires "AudioV9SpatialNativeProvider.cls"
