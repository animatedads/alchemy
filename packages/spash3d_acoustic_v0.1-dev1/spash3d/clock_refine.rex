/* clock_refine.rex -- per-segment FD/FC offset at 10 ms then sample resolution, speech band.
 * Architecture: Tom Dyer.  Coding: Claude (Opus 5.5), 31 Oct 2026.
 * Stage 1: 100 Hz detrended log envelope xcorr within coarse +-searchSec around the global offset.
 * Stage 2: speech-band waveform xcorr within +-40 ms (physical TDOA bound 27.5 ms + envelope bin) of stage 1.
 * usage: clock_refine.rex pcmDir workDir outTsv coarseOffsetSec [segSec] [searchSec]
 */
numeric digits 20
parse arg pcmDir workDir outTsv coarse segSec searchSec .
if segSec='' then segSec=600; if searchSec='' then searchSec=3
p=.AudioV9SpatialNativeProvider~new(value('AUDIO_V9_VOICE_ROOT',,'ENVIRONMENT')'/run/native/av9_spatial.bridge.json')
mode=value('SPASH_CHAIN_MODE',,'ENVIRONMENT'); if mode='' then mode='NAME'
ch=fcfdChains(pcmDir,mode)
sp=.directory~new                       /* speech-band chains at 8 kHz */
do feed over .array~of('FD','FC')
  c=.FeedChain~new(feed,8000)
  do f over ch[feed]~files
    base=filespec('name',f['PATH'])~changestr('.f32','')
    sel=workDir'/'base'_SPEECH.f32'
    if \sysFileExists(sel) then do
      mask=workDir'/'base'_SPEECH.mask.tsv'
      x=p~renderSelection(f['PATH'],mask,sel,8000,256,64)
    end
    c~add(sel,f['START'])
  end
  sp[feed]=c
end
/* segments: every FD-file x FC-file intersection (each file carries its own 1 s filename-time uncertainty) */
segs=.array~new
do fdf over ch['FD']~files
  do fcf over ch['FC']~files
    s0=max(fdf['START'],fcf['START'])+searchSec+1; s1=min(fdf['END'],fcf['END'])-searchSec-1
    if s1-s0>=60 then segs~append(s0 (s1-s0) filespec('name',fdf['PATH']) filespec('name',fcf['PATH']))
  end
end
o=.stream~new(outTsv); o~open('WRITE REPLACE')
o~lineout('fd_file'||'09'x||'fc_file'||'09'x||'segment_start'||'09'x||'minutes'||'09'x||'env_offset_s'||'09'x||'env_score'||'09'x||'env_z'||'09'x||'wave_offset_s'||'09'x||'wave_score')
a=workDir'/seg_fd.f32'; b=workDir'/seg_fc.f32'; ea=workDir'/seg_fd.env'; eb=workDir'/seg_fc.env'
do sg over segs
  parse var sg t len fdn fcn
  n=trunc(len)*8000
  sp['FD']~writeWindow(t,n,a); sp['FC']~writeWindow(t+coarse,n,b)
  x=p~envelope(a,ea,80,1,101); x=p~envelope(b,eb,80,1,101)
  r=p~xcorr(ea,eb,-searchSec*100,searchSec*100,1,1)
  pk=peak(r); z=pk['Z']
  envOff=coarse+pk['LAG']/100
  /* waveform refine around the envelope lag (8 kHz samples) */
  c=pk['LAG']*80
  r2=p~xcorr(a,b,c-320,c+320,1,1)
  pk2=peak(r2)
  waveOff=coarse+pk2['LAG']/8000
  line=fdn'09'x||fcn'09'x||sec2hms(t)'09'x||format(len/60,,1)'09'x||format(envOff,,2)'09'x||format(pk['SCORE'],,4)'09'x||format(z,,1)'09'x||format(waveOff,,5)'09'x||format(pk2['SCORE'],,4)
  o~lineout(line); say line
end
o~close
exit 0

::routine peak
  use arg r
  sc=r['SCORES']; lg=r['LAGS']; best=-9; bi=1; s=0; ss=0
  do i=1 to sc~items; s+=sc[i]; ss+=sc[i]**2; if sc[i]>best then do; best=sc[i]; bi=i; end; end
  k=sc~items; mu=s/k; v=ss/k-mu**2; if v<=0 then sd=1; else do; sd=v; do 60; sd=(sd+v/sd)/2; end; end
  d=.directory~new; d['LAG']=lg[bi]; d['SCORE']=best; d['Z']=(best-mu)/sd
  return d
::requires 'FeedChain.cls'
::requires 'AudioV9SpatialNativeProvider.cls'
