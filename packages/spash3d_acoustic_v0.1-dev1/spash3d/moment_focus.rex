/* moment_focus.rex -- re-render one moment with a hand-set pitch window (one speaker picked by ear + histogram).
 * Architecture: Tom Dyer (5 Nov 2026: "see if you can get a better higher female voice on that").
 * Coding: Claude (Opus 5.5).
 * Same chain as v7_profile_render: native harmonic-contrast pitch inside [loHz,hiHz] (512/80, 20 harmonics,
 * contrast >= minCon); device 386.8/193.4 Hz excluded; native voice mask, other tones at floorDb; then the
 * moment window [a,b] is cut, speech AGC (-18 dBFS) and written as 16 kHz MP3.
 * usage: moment_focus.rex pcm.f32 workDir a b loHz hiHz minCon floorDb outMp3 */
numeric digits 16
parse arg pcm w a b lo hi mc fl out
prov=.AudioV9SpatialNativeProvider~new(value('AUDIO_V9_VOICE_ROOT',,'ENVIRONMENT')'/run/native/av9_spatial.bridge.json')
flat=w'/flat.shape'; q=.stream~new(flat); q~open('WRITE REPLACE'); q~lineout('100'||'09'x||'1'); q~lineout('3800'||'09'x||'1'); q~close
x=prov~harmonicF0(pcm,w'/fh.tsv',8000,512,80,lo,hi,20,2000,mc)
hs=.stream~new(w'/fh.tsv'); hs~open('READ'); h=hs~linein
o=.stream~new(w'/ff.tsv'); o~open('WRITE REPLACE'); lifted=0
do while hs~lines>0
  parse value hs~linein with t '09'x f0 '09'x con
  wt=0; if f0>0 then wt=1
  if f0>0 then if abs(f0/386.8-1)<0.01 | abs(f0/193.4-1)<0.01 then wt=0
  if t>=a & t<=b then lifted+=wt
  o~lineout(t'09'x||wt'09'x||f0'09'x||con)
end
hs~close; o~close
x=prov~voiceMask(pcm,w'/fm.f32',w'/ff.tsv',flat,8000,512,128,fl,15,40,100,3800,0)
n=trunc((b-a)*8000); tf=.stream~new(w'/fm.f32'); tf~open('READ'); d=tf~charin(trunc(a*8000)*4+1,n*4); tf~close
c=.stream~new(w'/fc.f32'); c~open('WRITE REPLACE'); c~charout(d); c~close
x=prov~speechAgc(w'/fc.f32',w'/fa.f32',8000,-18,30,10,400,6,-1)
address system 'ffmpeg -v error -nostdin -y -f f32le -ar 8000 -ac 1 -i "'w'/fa.f32" -c:a libmp3lame -b:a 48k -ar 16000 "'out'"'
say filespec('name',out)':' lifted 'frames lifted in the moment,' lo||'-'||hi 'Hz, floor' fl 'dB'
::requires 'AudioV9SpatialNativeProvider.cls'
