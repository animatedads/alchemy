/* av_sync2.rex -- FD TP8 audio/video sync: for each video door/mechanical event, the strongest 10 ms of FD audio
 * within +-win s (native band blocks RMS, 128/80); histogram of (audio peak - video peak).
 * Architecture: Tom Dyer.  Coding: Claude (Opus 5.5), 31 Oct 2026.
 * usage: av_sync2.rex eventsTsv fdPcm outTsv [win] [binMs]
 */
numeric digits 16
parse arg evF pcm outF win binMs .
if win='' then win=3; if binMs='' then binMs=40
prov=.AudioV9SpatialNativeProvider~new(value('AUDIO_V9_VOICE_ROOT',,'ENVIRONMENT')'/run/native/av9_spatial.bridge.json')
work=value('SPASH_WORK',,'ENVIRONMENT'); tmp=work'/avs.f32'
nTot=stream(pcm,'C','QUERY SIZE')%4
o=.stream~new(outF'.events.tsv'); o~open('WRITE REPLACE')
o~lineout('event_id'||'09'x||'class'||'09'x||'video_peak_s'||'09'x||'audio_peak_s'||'09'x||'audio_minus_video_ms'||'09'x||'peak_over_median_db')
hist=.directory~new; n=0
s=.stream~new(evF); s~open('READ'); h=s~linein
do while s~lines>0
  c=s~linein~makeArray('09'x); if c~items<7 then iterate
  if c[1]<>'FD' then iterate
  vt=c[7]/1000; st=trunc((vt-win)*8000); if st<0 then iterate
  len=trunc(2*win*8000); if st+len>nTot then iterate
  i=.stream~new(pcm); i~open('READ'); buf=i~charin(st*4+1,len*4); i~close
  w=.stream~new(tmp); w~open('WRITE REPLACE'); w~charout(buf); w~close
  bl=prov~bandBlocks(tmp,8000,128,80,1,1,100,3800)
  r=.array~new; do d over bl; r~append(d['RMS']); end
  bi=1; do k=1 to r~items; if r[k]>r[bi] then bi=k; end
  srt=r~copy~sortWith(.NumericComparator~new); med=max(srt[(srt~items+1)%2],1e-12)
  at=(st+bl[bi]['START']+64)/8000
  d=(at-vt)*1000; db=20*RxCalcLog10(r[bi]/med,16)
  o~lineout(c[4]'09'x||c[5]'09'x||format(vt,,3)'09'x||format(at,,3)'09'x||format(d,,0)'09'x||format(db,,1))
  if db>=10 then do
    b=trunc((d+win*1000)/binMs); if hist~hasIndex(b) then hist[b]=hist[b]+1; else hist[b]=1; n+=1
  end
end
s~close; o~close
srt=.array~new; do b over hist~allIndexes; srt~append(right(hist[b],6,'0') b); end; srt=srt~sort
o=.stream~new(outF); o~open('WRITE REPLACE'); o~lineout('audio_minus_video_ms'||'09'x||'events')
do k=srt~items to max(1,srt~items-9) by -1
  parse value srt[k] with cnt b; ms=b*binMs-win*1000+binMs/2
  o~lineout(ms'09'x||cnt+0); say 'offset' ms 'ms events' cnt+0
end
o~close
say 'events with a >=10 dB audio peak:' n
::requires 'AudioV9SpatialNativeProvider.cls'
::requires 'rxmath' LIBRARY
