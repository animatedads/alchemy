/* test_gccphat.rex -- native GCC-PHAT on the Audio V9 120 ms fixture and on a known shifted speech segment. Coding: Claude (Opus 5.5). */
numeric digits 16
root=value('AUDIO_V9_VOICE_ROOT',,'ENVIRONMENT')
p=.AudioV9SpatialNativeProvider~new(root'/run/native/av9_spatial.bridge.json')
r=p~gccPhat(root'/run/test/a120.f32',root'/run/test/b120.f32',8000,1200,300,3400)
say 'fixture: lag' r[1]['LAG'] 'sharp' r[1]['SHARP']
if abs(r[1]['LAG']-960)>1 then do; say 'FAIL fixture'; exit 1; end
/* POI1 voice shifted by 17 samples into the second channel, with independent TP28 noise added at both */
s=.stream~new('/home/claude/work/pcm/poi1.f32'); s~open('READ'); v=s~charin(1,8000*4*1); s~close
z=copies('00000000'x,17)
a=v; b=z||v~left(length(v)-17*4)
call charout '/tmp/ga.f32',a; call stream '/tmp/ga.f32','C','CLOSE'; call charout '/tmp/gb.f32',b; call stream '/tmp/gb.f32','C','CLOSE'
r=p~gccPhat('/tmp/ga.f32','/tmp/gb.f32',8000,240,300,3400)
say 'voice: lag' r[1]['LAG'] 'sharp' r[1]['SHARP'] 'second' r[2]['LAG'] r[2]['SHARP']
if abs(r[1]['LAG']-17)>0.5 then do; say 'FAIL voice'; exit 1; end
say 'PASS test_gccphat checks=2'
::requires 'AudioV9SpatialNativeProvider.cls'
