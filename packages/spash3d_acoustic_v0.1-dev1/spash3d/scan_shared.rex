/* scan_shared.rex -- find windows where FD and FC hear the same sound (speech band), clock-model aligned.
 * Architecture: Tom Dyer.  Coding: Claude (Opus 5.5), 31 Oct 2026.
 * For each window: Audio V9 native xcorr of the speech-band FD and FC signals over model lag +-searchMs.
 * usage: scan_shared.rex pcmDir workDir outTsv clockA clockB [winSec] [searchMs]
 *   clock: fc_minus_fd_s = clockA + clockB*hours_since_12:00:00 (continuous chains)
 */
numeric digits 20
parse arg pcmDir workDir outTsv cA cB winSec searchMs stepSec .
if winSec='' then winSec=4; if searchMs='' then searchMs=80; if stepSec='' then stepSec=winSec
p=.AudioV9SpatialNativeProvider~new(value('AUDIO_V9_VOICE_ROOT',,'ENVIRONMENT')'/run/native/av9_spatial.bridge.json')
ch=fcfdChains(pcmDir,'CONTINUOUS')
sp=.directory~new
do feed over .array~of('FD','FC')
  c=.FeedChain~new(feed,8000)
  do f over ch[feed]~files
    c~add(workDir'/'filespec('name',f['PATH'])~changestr('.f32','')'_SPEECH.f32',f['START'])
  end
  sp[feed]=c
end
t0=max(ch['FD']~startSec,ch['FC']~startSec)+5; t1=min(ch['FD']~endSec,ch['FC']~endSec)-winSec-5
n=winSec*8000; a=workDir'/sh_fd.f32'; b=workDir'/sh_fc.f32'; r=searchMs*8
o=.stream~new(outTsv); o~open('WRITE REPLACE')
o~lineout('fd_time'||'09'x||'fc_time'||'09'x||'model_offset_s'||'09'x||'peak_lag_ms'||'09'x||'peak_score'||'09'x||'peak_z'||'09'x||'rms_fd'||'09'x||'rms_fc')
cnt=0
do t=t0 to t1 by stepSec
  off=cA+cB*(t-hms2sec('120000'))/3600
  sp['FD']~writeWindow(t,n,a); sp['FC']~writeWindow(t+off,n,b)
  x=p~xcorr(a,b,-r,r,1,2)
  sc=x['SCORES']; best=-9; bi=1; s=0; ss=0
  do i=1 to sc~items; v=sc[i]; s+=v; ss+=v*v; if v>best then do; best=v; bi=i; end; end
  k=sc~items; mu=s/k; var=ss/k-mu*mu; sd=1; if var>0 then do; sd=var; do 40; sd=(sd+var/sd)/2; end; end
  m=p~measure(a,b,8000,10,1)
  line=sec2hms(t)'09'x||sec2hms(t+off)'09'x||format(off,,4)'09'x||format(x['LAGS'][bi]/8,,3)'09'x||format(best,,4)'09'x||format((best-mu)/sd,,1)'09'x||format(m~rmsA,,,,2)'09'x||format(m~rmsB,,,,2)
  o~lineout(line); cnt+=1
  if cnt//250=0 then say cnt 'windows' sec2hms(t)
end
o~close
say 'DONE windows' cnt
exit 0
::requires 'FeedChain.cls'
::requires 'AudioV9SpatialNativeProvider.cls'
