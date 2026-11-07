/* ring_scan.rex -- does a short FD sound repeat sample-for-sample (a played-back ringtone) within a longer span?
 * Coding: Claude (Opus 5.5).  Band 900-2600 Hz (native render_select), native template_scan.
 * usage: ring_scan.rex long.f32 templStartS templSec [lo hi] */
numeric digits 16
parse arg long ts tl lo hi .
if lo='' then lo=900; if hi='' then hi=2600
prov=.AudioV9SpatialNativeProvider~new(value('AUDIO_V9_VOICE_ROOT',,'ENVIRONMENT')'/run/native/av9_spatial.bridge.json')
work=value('SPASH_WORK',,'ENVIRONMENT')
n=.stream~new(long)~query('size')/4
m=.stream~new(work'/rs.mask.tsv'); m~open('WRITE REPLACE'); m~lineout('s'||'09'x||'e'||'09'x||'lo'||'09'x||'hi'||'09'x||'w'); m~lineout(0'09'x||n'09'x||lo'09'x||hi'09'x||1); m~close
bf=work'/rs_band.f32'; x=prov~renderSelection(long,work'/rs.mask.tsv',bf,8000,256,64)
i=.stream~new(bf); i~open('READ'); d=i~charin(trunc(ts*8000)*4+1,trunc(tl*8000)*4); i~close
t=work'/rs_t.f32'; o=.stream~new(t); o~open('WRITE REPLACE'); o~charout(d); o~close
r=prov~templateScan(bf,t,8,15)
do h over r; say format(h['OFFSET']/8000,,2)~right(8) 's  score' format(h['SCORE'],,3) ' z' format(h['Z'],,1); end
::requires 'AudioV9SpatialNativeProvider.cls'
