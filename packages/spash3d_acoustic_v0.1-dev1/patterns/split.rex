/* split.rex -- one file per voice group: each group's own frame-by-frame pitch lines (multiF0, harmonics of the
 * other voices already cancelled) drive the native voice mask; everything else at floorDb.
 * Architecture: Tom Dyer (6 Nov 2026: "then we want to try to split each out to a separate file").
 * Coding: Claude (Opus 5.5).
 * Groups: blocks by median pitch at 1/lv octave; groups with >= minSec of voice get a file.
 * Render: cleaned (tilted) signal of the same window; voice mask 512/128, width 15 Hz, smoothing 40 ms, no shape
 * term; the clip (pad trimmed) gets the native speech AGC (-18 dBFS, up to +48 dB) and MP3 48 kb/s 16 kHz.
 * usage: split.rex blocksFile clnF32 pad clipLen lv minSec floorDb outPrefix */
numeric digits 16
parse arg bf cln pad clen lv minSec fl outP
prov=.AudioV9SpatialNativeProvider~new(value('AUDIO_V9_VOICE_ROOT',,'ENVIRONMENT')'/run/native/av9_spatial.bridge.json')
w=filespec('location',cln); n=stream(cln,'C','QUERY SIZE')/4; nFr=trunc(n/80)
grp=.directory~new; secs=.directory~new
s=.stream~new(bf); s~open('READ')
do while s~lines>0
  parse value s~linein with ta tb f0 st pts
  k=trunc(lv*RxCalcLog(f0/60,16)/RxCalcLog(2,16))
  if \grp~hasIndex(k) then do; grp[k]=.directory~new; secs[k]=0; end
  secs[k]+=tb-ta
  loop pv over pts~makeArray(','); parse var pv pt ':' pf; grp[k][format(pt*100,,0)]=pf; end
end
s~close
flat=w'sp_flat.shape'; q=.stream~new(flat); q~open('WRITE REPLACE'); q~lineout('100'||'09'x||'1'); q~lineout('3800'||'09'x||'1'); q~close
made=0
loop k over grp~allIndexes~sortWith(.NumericComparator~new)
  if secs[k]<minSec then iterate
  lo=format(60*RxCalcPower(2,k/lv,16),,0); hi=format(60*RxCalcPower(2,(k+1)/lv,16),,0)
  ft=w'sp_'k'.frames.tsv'; o=.stream~new(ft); o~open('WRITE REPLACE'); lit=0
  loop i=0 to nFr-1
    t=format(0.064+i*0.01,,3); key=format(t*100,,0)          /* multiF0 frame centres: (st + 512)/8000 */
    if grp[k]~hasIndex(key) then do; o~lineout(t'09'x||'1'||'09'x||grp[k][key]||'09'x||'1'); lit+=1; end
    else o~lineout(t'09'x||'0'||'09'x||'0'||'09'x||'0')
  end
  o~close
  x=prov~voiceMask(cln,w'sp_out.f32',ft,flat,8000,512,128,fl,15,40,100,3800,0)
  st=.stream~new(w'sp_out.f32'); st~open('READ'); d=st~charin(trunc(pad*8000)*4+1,trunc(clen*8000)*4); st~close
  c=.stream~new(w'sp_cut.f32'); c~open('WRITE REPLACE'); c~charout(d); c~close
  x=prov~speechAgc(w'sp_cut.f32',w'sp_agc.f32',8000,-18,48,10,400,6,-1)
  nm=outP'_voice_'lo'-'hi'Hz.mp3'
  address system 'ffmpeg -v error -nostdin -y -f f32le -ar 8000 -ac 1 -i "'w'sp_agc.f32" -c:a libmp3lame -b:a 48k -ar 16000 "'nm'"'
  say filespec('name',nm)':' format(secs[k],,1) 's of voice in' lit 'frames'; made+=1
end
say made 'voice files'
::requires 'rxmath' LIBRARY
::requires 'AudioV9SpatialNativeProvider.cls'
