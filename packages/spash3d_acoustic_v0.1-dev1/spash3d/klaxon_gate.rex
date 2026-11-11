/* klaxon_gate.rex -- Tom's method: remove the klaxon by TIME (gate its bursts), then amplify; the voice is around it.
 * Architecture: Tom Dyer (method shown 31 Oct 2026: klaxon removed, +22 dB, voice exposed).  Coding: Claude (Opus 5.5).
 * Klaxon frame (32 ms, native band blocks 1024/256, 64 log bands 250-3400 Hz):
 *   frame RMS >= median frame RMS + loudDb  AND  spectral flatness <= flatMax (tonal), in runs >= 0.5 s,
 *   plus guardMs either side.
 * Gated frames get no keep-box (zero); kept frames keep 250-3400 Hz.  Audio V9 native render_select, then gain.
 * usage: klaxon_gate.rex in.f32 out.f32 gatesTsv [gainDb] [loudDb] [flatMax] [guardMs]
 */
numeric digits 16
parse arg inF outF gatesTsv gainDb loudDb flatMax guardMs .
if gainDb='' then gainDb=22; if loudDb='' then loudDb=15; if flatMax='' then flatMax=0.15; if guardMs='' then guardMs=96
prov=.AudioV9SpatialNativeProvider~new(value('AUDIO_V9_VOICE_ROOT',,'ENVIRONMENT')'/run/native/av9_spatial.bridge.json')
hop=256
bl=prov~bandBlocks(inF,8000,1024,hop,1,64,250,3400)
n=stream(inF,'C','QUERY SIZE')%4
rms=.array~new; do d over bl; rms~append(d['RMS']); end
srt=rms~copy~sortWith(.NumericComparator~new); med=max(srt[(srt~items+1)%2],1e-12)
thr=med*RxCalcPower(10,loudDb/20,16)
flag=.array~new
do i=1 to bl~items
  d=bl[i]; lg=0; ar=0; k=0
  do v over d['BANDS']; v=max(v,1e-30); lg+=RxCalcLog(v,16); ar+=v; k+=1; end
  flat=RxCalcExp(lg/k,16)/(ar/k)
  flag[i]=(d['RMS']>=thr & flat<=flatMax)
end
/* a klaxon burst lasts seconds: drop flagged runs shorter than minRunMs (keeps short impulses, e.g. knocks) */
minRun=trunc(500/32+0.5); i=1
do while i<=bl~items
  if \flag[i] then do; i+=1; iterate; end
  j=i; do while j<bl~items; if \flag[j+1] then leave; j+=1; end
  if j-i+1<minRun then do k=i to j; flag[k]=0; end
  i=j+1
end
g=trunc(guardMs/32+0.5); gate=.array~new
do i=1 to bl~items
  gate[i]=0
  do j=max(1,i-g) to min(bl~items,i+g); if flag[j] then do; gate[i]=1; leave; end; end
end
mask=outF'.mask.tsv'
m=.stream~new(mask); m~open('WRITE REPLACE'); m~lineout('start'||'09'x||'end'||'09'x||'lo'||'09'x||'hi'||'09'x||'w')
o=.stream~new(gatesTsv); o~open('WRITE REPLACE'); o~lineout('gate_start_s'||'09'x||'gate_end_s')
inG=0; gs=0; gated=0
do i=1 to bl~items
  st=bl[i]['START']+384; en=st+hop
  if i=1 then st=0
  if i=bl~items then en=n
  if en>n then en=n
  if st>=en then iterate
  if gate[i] then do; gated+=1; if \inG then do; inG=1; gs=st; end; end
  else do
    if inG then do; inG=0; o~lineout(format(gs/8000,,3)'09'x||format(st/8000,,3)); end
    m~lineout(st'09'x||en'09'x||'250'||'09'x||'3400'||'09'x||'1')
  end
end
if inG then o~lineout(format(gs/8000,,3)'09'x||format(n/8000,,3))
m~close; o~close
gl=RxCalcPower(10,gainDb/20,16)/2; tmp=outF'.gain.f32'
x=prov~renderAlignedMix(inF,inF,tmp,0,gl,gl)
x=prov~renderSelection(tmp,mask,outF,8000,1024,256)
call sysFileDelete tmp
say filespec('name',inF) 'gated' format(100*gated/bl~items,,1)'% of frames' 'gain' gainDb'dB'
exit 0
::requires 'AudioV9SpatialNativeProvider.cls'
::requires 'rxmath' LIBRARY
