/* clock_align.rex -- measure FD->FC clock offset across the overlap with Audio V9's native spatial measure.
 * Architecture: Tom Dyer.  Coding: Claude (Opus 5.5).
 * usage: clock_align.rex pcmDir outTsv [windowSec] [stepSec] [maxEnvMs]
 * A = FD window, B = FC window at the same nominal wall-clock time.
 * Positive lag => FC hears it later than FD (sign convention of av9_spatial_provider.c).
 */
numeric digits 20
parse arg pcmDir outTsv winSec stepSec maxEnv .
if winSec='' then winSec=60; if stepSec='' then stepSec=600; if maxEnv='' then maxEnv=3000
ch=fcfdChains(pcmDir); fd=ch['FD']; fc=ch['FC']
t0=max(fd~startSec,fc~startSec)+5; t1=min(fd~endSec,fc~endSec)-winSec-5
prov=.AudioV9SpatialNativeProvider~new(value('AUDIO_V9_VOICE_ROOT',,'ENVIRONMENT')'/run/native/av9_spatial.bridge.json')
tmp=value('TMPDIR',,'ENVIRONMENT'); if tmp='' then tmp='/tmp'
a=tmp'/clk_fd.f32'; b=tmp'/clk_fc.f32'; n=winSec*8000
call sysFileDelete outTsv
o=.stream~new(outTsv); o~open('WRITE REPLACE')
o~lineout('wall_clock'||'09'x||'env_lag_ms'||'09'x||'env_score'||'09'x||'refined_lag_ms'||'09'x||'refined_score'||'09'x||'refined_coherence'||'09'x||'crest_fd'||'09'x||'crest_fc'||'09'x||'ratio_db')
do t=t0 to t1 by stepSec
  fd~writeWindow(t,n,a); fc~writeWindow(t,n,b)
  m=prov~measure(a,b,8000,maxEnv,30)
  line=sec2hms(t)'09'x||m~envelopeLagMs'09'x||format(m~envelopeScore,,4)'09'x||m~refinedLagMs'09'x||format(m~refinedScore,,4)'09'x||format(m~refinedCoherence,,4)'09'x||format(m~crestA,,2)'09'x||format(m~crestB,,2)'09'x||format(m~ratioDb,,2)
  o~lineout(line); say line
end
o~close
exit 0
::requires 'FeedChain.cls'
::requires 'AudioV9SpatialNativeProvider.cls'
