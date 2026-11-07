/* smooth_test.rex -- COMPREHENSION TESTING ONLY, kept apart from the evidence renders.
 * Architecture: Tom Dyer (6 Nov 2026: add a smoother; the aggressive cuts leave a jagged shape; "talking through a
 *   fan"; loss at 8k).  Coding: Claude (Opus 5.5).
 * Input: a listening clip as received (MP3), decoded to 16 kHz mono f32 (container decode only).
 *   s1 smooth: native spectral smoother (held envelope 60 ms, +-2 bins, fill <= 12 dB)
 *   s2 smooth + tilt (native band select: 90-250 Hz x0.15, 250-600 x0.4, 600-1200 x0.8, 1200-7600 x1)
 *   s3 smooth + bandwidth (4-7.2 kHz rebuilt from 2.0-3.6 kHz, -12 dB at 4 kHz, -6 dB/kHz) + tilt
 *   s4 strong smooth (held envelope 120 ms, +-3 bins, fill <= 18 dB) + bandwidth + tilt
 * each: native speech AGC (-18 dBFS, 16 kHz), MP3 64 kb/s 16 kHz (container encode only).
 * usage: smooth_test.rex in.f32 workDir outPrefix */
numeric digits 16
parse arg inF w outP
prov=.AudioV9SpatialNativeProvider~new(value('AUDIO_V9_VOICE_ROOT',,'ENVIRONMENT')'/run/native/av9_spatial.bridge.json')
n=stream(inF,'C','QUERY SIZE')/4
tm=.stream~new(w'/tilt16.tsv'); tm~open('WRITE REPLACE'); tm~lineout('start'||'09'x||'end'||'09'x||'lo'||'09'x||'hi'||'09'x||'w')
loop row over .array~of('90 7600 0.15','250 7600 0.4','600 7600 0.8','1200 7600 1')
  parse var row tlo thi tw; tm~lineout('0'||'09'x||n||'09'x||tlo||'09'x||thi||'09'x||tw)
end
tm~close
x=prov~spectralSmooth(inF,w'/s1.f32',16000,512,128,60,2,12,0)
x=prov~renderSelection(w'/s1.f32',w'/tilt16.tsv',w'/s2.f32',16000,512,128)
x=prov~spectralSmooth(inF,w'/s3a.f32',16000,512,128,60,2,12,-12)
x=prov~renderSelection(w'/s3a.f32',w'/tilt16.tsv',w'/s3.f32',16000,512,128)
x=prov~spectralSmooth(inF,w'/s4a.f32',16000,512,128,120,3,18,-12)
x=prov~renderSelection(w'/s4a.f32',w'/tilt16.tsv',w'/s4.f32',16000,512,128)
loop v over .array~of('s1|smooth','s2|smooth_tilt','s3|smooth_bandwidth_tilt','s4|strongsmooth_bandwidth_tilt')
  parse var v f '|' lab
  x=prov~speechAgc(w'/'f'.f32',w'/'f'_agc.f32',16000,-18,30,10,400,6,-1)
  address system 'ffmpeg -v error -nostdin -y -f f32le -ar 16000 -ac 1 -i "'w'/'f'_agc.f32" -c:a libmp3lame -b:a 64k -ar 16000 "'outP'_'lab'.mp3"'
end
say 'written' outP'_*.mp3'
::requires 'AudioV9SpatialNativeProvider.cls'
