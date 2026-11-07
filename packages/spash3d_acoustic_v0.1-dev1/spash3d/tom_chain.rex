/* tom_chain.rex -- +24 dB float gain, then stationary suppression (klaxon/hum/whine) in the 250-3400 Hz speech band.
 * Architecture: Tom Dyer.  Coding: Claude (Opus 5.5), 31 Oct 2026.
 * usage: tom_chain.rex in.f32 out.f32 [gainDb] [percentile] [over] [floor] */
numeric digits 16
parse arg inF outF gainDb pct over fl .
if gainDb='' then gainDb=24; if pct='' then pct=50; if over='' then over=1.5; if fl='' then fl=0.05
prov=.AudioV9SpatialNativeProvider~new(value('AUDIO_V9_VOICE_ROOT',,'ENVIRONMENT')'/run/native/av9_spatial.bridge.json')
g=RxCalcPower(10,gainDb/20,16)/2; tmp=outF'.gain.f32'
x=prov~renderAlignedMix(inF,inF,tmp,0,g,g)
x=prov~suppressStationary(tmp,outF,8000,1024,256,pct,over,fl,250,3400)
call sysFileDelete tmp
exit 0
::requires 'AudioV9SpatialNativeProvider.cls'
::requires 'rxmath' LIBRARY
