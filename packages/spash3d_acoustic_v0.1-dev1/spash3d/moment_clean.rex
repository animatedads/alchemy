/* moment_clean.rex -- re-render one moment for a noisy clip: rumble out first, then the union of voice profiles.
 * Architecture: Tom Dyer (5 Nov 2026: "37 has got a lot of noise").  Coding: Claude (Opus 5.5).
 * Why: in moment 37 two thirds of the energy sits below 100 Hz and swings by 28 dB (wind / handling rumble).
 * The union mask keeps out-of-band bins at the floor (-14 dB), so the rumble stayed louder than the speech and
 * the AGC levelled on it.  The native enhancer zeroes bins outside [loHz,hiHz] and removes stationary noise
 * (min statistics + MMSE-LSA), so it runs first; the union mask then uses the existing per-profile frames.
 * usage: moment_clean.rex pcm.f32 workDir framesList a b loHz over floorDb outMp3 */
numeric digits 16
parse arg pcm w lst a b lo ov fl out
prov=.AudioV9SpatialNativeProvider~new(value('AUDIO_V9_VOICE_ROOT',,'ENVIRONMENT')'/run/native/av9_spatial.bridge.json')
src=pcm
if ov>0 then do; x=prov~enhance(pcm,w'/ce.f32',8000,256,64,1.5,0.98,ov,0.1,lo,3600); src=w'/ce.f32'; end
x=prov~voiceMaskUnion(src,w'/cu.f32',lst,8000,512,128,fl,15,40,lo,3800)
n=trunc((b-a)*8000); tf=.stream~new(w'/cu.f32'); tf~open('READ'); d=tf~charin(trunc(a*8000)*4+1,n*4); tf~close
c=.stream~new(w'/cc.f32'); c~open('WRITE REPLACE'); c~charout(d); c~close
x=prov~speechAgc(w'/cc.f32',w'/ca.f32',8000,-18,30,10,400,6,-1)
address system 'ffmpeg -v error -nostdin -y -f f32le -ar 8000 -ac 1 -i "'w'/ca.f32" -c:a libmp3lame -b:a 48k -ar 16000 "'out'"'
say filespec('name',out) 'written'
::requires 'AudioV9SpatialNativeProvider.cls'
