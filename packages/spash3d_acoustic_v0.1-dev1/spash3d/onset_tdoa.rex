/* onset_tdoa.rex -- FC-FD delay of sharp events from first-arrival onset times (robust to FD clipping and ringing).
 * Architecture: Tom Dyer.  Coding: Claude (Opus 5.5), 31 Oct 2026.
 * For each candidate (door_bangs.tsv, score >= minScore): 1 ms RMS (native band blocks 16/8, 1 band) of FD and FC
 * over [-150, +150] ms; onset = first 1 ms block >= pre-event median (first 100 ms) + kDb. lag = FC onset - FD onset.
 * usage: onset_tdoa.rex candTsv outTsv [minScore] [kDb]
 */
numeric digits 16
parse arg candF outF minScore kDb .
if minScore='' then minScore=0.3; if kDb='' then kDb=15
parse value value('SPASH_CLOCK',,'ENVIRONMENT') with cA cB
prov=.AudioV9SpatialNativeProvider~new(value('AUDIO_V9_VOICE_ROOT',,'ENVIRONMENT')'/run/native/av9_spatial.bridge.json')
ch=fcfdChains(value('SPASH_PCM',,'ENVIRONMENT'),'CONTINUOUS')
work=value('SPASH_WORK',,'ENVIRONMENT'); a=work'/ot_fd.f32'; b=work'/ot_fc.f32'
o=.stream~new(outF); o~open('WRITE REPLACE')
o~lineout('fd_time'||'09'x||'fc_file'||'09'x||'fd_onset_ms'||'09'x||'fc_onset_ms'||'09'x||'onset_lag_ms'||'09'x||'fd_rise_db'||'09'x||'fc_rise_db'||'09'x||'xcorr_score'||'09'x||'fd_lf_over_speech_db'||'09'x||'fc_lf_over_speech_db'||'09'x||'class')
s=.stream~new(candF); s~open('READ'); h=s~linein
do while s~lines>0
  c=s~linein~makeArray('09'x); if c~items<7 then iterate
  if c[7]<minScore then iterate
  parse value c[1] with hh ':' mm ':' ss
  t=hh*3600+mm*60+ss; off=cA+cB*(t-hms2sec('120000'))/3600
  ch['FD']~writeWindow(t-0.15,2400,a); ch['FC']~writeWindow(t+off-0.15,2400,b)
  fd=onset(prov,a,kDb); fc=onset(prov,b,kDb)
  wfd=lfRatio(prov,a); wfc=lfRatio(prov,b)
  fcf=fcFile(t+off)
  if fd~word(1)='NA' | fc~word(1)='NA' then lag='NA'; else lag=format(fc~word(1)-fd~word(1),,1)
  o~lineout(c[1]'09'x||fcf'09'x||fd~word(1)'09'x||fc~word(1)'09'x||lag'09'x||fd~word(2)'09'x||fc~word(2)'09'x||c[7]'09'x||wfd'09'x||wfc'09'x||klass(wfd,wfc))
end
s~close; o~close
exit 0
onset: procedure
  use arg prov, f, kDb
  /* speech band 300-3400 Hz only (wind buffeting is mostly < 300 Hz); 8 ms windows, 1 ms hop */
  bl=prov~bandBlocks(f,8000,64,8,1,1,300,3400)
  r=.array~new; do d over bl; r~append(max(RxCalcSqrt(max(d['BANDS'][1],0),16),1e-9)); end
  pre=.array~new; do k=1 to 100; pre~append(r[k]); end
  pre=pre~sortWith(.NumericComparator~new); base=pre[50]
  thr=base*RxCalcPower(10,kDb/20,16)
  do k=101 to r~items
    if r[k]>=thr then return format(k-150,,0) format(20*RxCalcLog10(r[k]/base,16),,1)
  end
  return 'NA NA'
lfRatio: procedure
  /* power density 30-319 Hz over 319-3400 Hz, dB, on the 300 ms window (2 log bands) */
  use arg prov, f
  bl=prov~bandBlocks(f,8000,256,256,9,2,30,3400)
  lo=0; hi=0; do d over bl; lo+=d['BANDS'][1]; hi+=d['BANDS'][2]; end
  if lo<=0 | hi<=0 then return 'NA'
  return format(10*RxCalcLog10(lo/hi,16),,1)
klass: procedure
  use arg wfd, wfc
  if \datatype(wfc,'N') then return 'NA'
  /* FC alone: FD carries a constant 103-137 Hz hum, so comparing with FD is meaningless.
     Threshold from Tom Dyer's listening labels 31 Oct 2026: wind 39.8/41.6 dB; car doors/bump 25.3-33.4 dB. */
  if wfc>=36 then return 'WIND_FC'
  return 'PROPAGATING'
fcFile: procedure
  use arg t
  if t<43760 then return 'tp28'; if t<45526 then return 'tp29'; if t<47224 then return 'tp30'
  if t<48921 then return 'tp31'; if t<50624 then return 'tp32'; if t<52320 then return 'tp33'; return 'tp34'
::requires 'FeedChain.cls'
::requires 'AudioV9SpatialNativeProvider.cls'
::requires 'rxmath' LIBRARY
