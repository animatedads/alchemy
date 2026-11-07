/* notch_filter.rex -- Tom's chain: +24 dB float gain, then speech band with tonal lines (klaxon, hum) notched out.
 * Architecture: Tom Dyer.  Coding: Claude (Opus 5.5), 31 Oct 2026.
 * Tracking notch: every 32 ms frame (native band blocks, 1024 FFT, 160 log bands 250-3400 Hz) a band is tonal
 * when it is >= lineDb above the median of its +-8 neighbours and a local maximum. Those bands are cut for that
 * frame only, so a wobbling klaxon is followed. Filter = Audio V9 native render_select with time-varying keep-boxes.
 * usage: notch_filter.rex in.f32 out.f32 statsTsv [gainDb] [lineDb]
 */
numeric digits 16
parse arg inF outF statsTsv gainDb lineDb .
if gainDb='' then gainDb=24; if lineDb='' then lineDb=12
prov=.AudioV9SpatialNativeProvider~new(value('AUDIO_V9_VOICE_ROOT',,'ENVIRONMENT')'/run/native/av9_spatial.bridge.json')
nb=160; f0=250; f1=3400; hop=256
bl=prov~bandBlocks(inF,8000,1024,hop,1,nb,f0,f1)
edges=.array~new; do k=0 to nb; edges~append(f0*RxCalcPower(f1/f0,k/nb,16)); end
n=stream(inF,'C','QUERY SIZE')%4
mask=outF'.mask.tsv'
m=.stream~new(mask); m~open('WRITE REPLACE'); m~lineout('start'||'09'x||'end'||'09'x||'lo'||'09'x||'hi'||'09'x||'w')
cutsTotal=0; frames=0; hist=.directory~new
do i=1 to bl~items
  d=bl[i]; b=d['BANDS']
  st=d['START']+384; en=st+hop          /* frame centre region (1024 frame, centre 512, +-128) */
  if i=1 then st=0
  if i=bl~items then en=n
  if en>n then en=n
  if st>=en then iterate
  cut=.array~new
  do k=1 to nb
    v=max(b[k],1e-30)
    if k>1 then if b[k-1]>b[k] then iterate
    if k<nb then if b[k+1]>b[k] then iterate
    nbr=.array~new; do j=max(1,k-8) to min(nb,k+8); if abs(j-k)>1 then nbr~append(max(b[j],1e-30)); end
    nbr=nbr~sortWith(.NumericComparator~new); med=nbr[(nbr~items+1)%2]
    if 10*RxCalcLog10(v/med,16)>=lineDb then do
      cut~append(k)
      hz=trunc(edges[k]/25)*25; if hist~hasIndex(hz) then hist[hz]=hist[hz]+1; else hist[hz]=1
    end
  end
  /* keep boxes for this frame: speech band minus [edge(k-1), edge(k+2)] around each cut band */
  lo=f0
  do k over cut
    a=edges[max(1,k-1)]; c=edges[min(nb+1,k+2)]
    if a>lo+4 then m~lineout(st'09'x||en'09'x||format(lo,,2)'09'x||format(a,,2)'09'x||'1')
    lo=max(lo,c)
  end
  if lo<f1-4 then m~lineout(st'09'x||en'09'x||format(lo,,2)'09'x||f1'09'x||'1')
  cutsTotal+=cut~items; frames+=1
end
m~close
g=RxCalcPower(10,gainDb/20,16)/2
tmp=outF'.gain.f32'
x=prov~renderAlignedMix(inF,inF,tmp,0,g,g)
x=prov~renderSelection(tmp,mask,outF,8000,1024,256)
call sysFileDelete tmp
o=.stream~new(statsTsv); o~open('WRITE REPLACE')
o~lineout('gain_db'||'09'x||gainDb); o~lineout('line_threshold_db'||'09'x||lineDb)
o~lineout('frames'||'09'x||frames); o~lineout('tonal_cuts_per_frame'||'09'x||format(cutsTotal/max(1,frames),,2))
idx=hist~allIndexes~sortWith(.NumericComparator~new)
do h over idx; if hist[h]>=frames*0.10 then o~lineout('frequent_line_hz_'h'-'h+25||'09'x||format(100*hist[h]/frames,,0)'% of frames'); end
o~close
say filespec('name',inF) 'frames' frames 'cuts/frame' format(cutsTotal/max(1,frames),,2)
exit 0
::requires 'AudioV9SpatialNativeProvider.cls'
::requires 'rxmath' LIBRARY
