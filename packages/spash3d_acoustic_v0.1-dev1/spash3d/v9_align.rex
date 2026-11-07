/* v9_align.rex -- place a segment of the old Python V9 scene render (0.5*CamA + 0.5*CamB, amp32, unaligned)
 * on our FD / FC continuous chains, by speech-band envelope correlation.
 * Architecture: Tom Dyer.  Coding: Claude (Opus 5.5), 31 Oct 2026.
 * Speech band: Audio V9 native render_select 300-3400 Hz.  Envelope: native, 80-sample bins (10 ms), log dB, 3 s detrend.
 * usage: v9_align.rex v9seg.f32 v9StartHHMMSS winSec maxLagSec [stepSec]
 *   v9StartHHMMSS = wall-clock time of the first sample of v9seg (render start 00:00:01 + ogg offset)
 *   positive lag => feed is LATER than the v9 render.
 */
numeric digits 16
parse arg v9 v9Start winSec maxLag stepSec .
if stepSec='' then stepSec=winSec
prov=.AudioV9SpatialNativeProvider~new(value('AUDIO_V9_VOICE_ROOT',,'ENVIRONMENT')'/run/native/av9_spatial.bridge.json')
ch=fcfdChains(value('SPASH_PCM',,'ENVIRONMENT'),'CONTINUOUS')
work=value('SPASH_WORK',,'ENVIRONMENT')
t0=hms2sec(v9Start~changestr(':',''))
segSec=.stream~new(v9)~query('size')/4/8000
say 'v9 segment' v9 'starts' sec2hms(t0) 'length' format(segSec,,1)'s'
say 'win_start'~left(12) 'feed' 'lag_s'~right(8) 'score'~right(7) 'z'~right(6) 'second_z'~right(9)
do ws=0 to segSec-winSec by stepSec
  vw=work'/v9a_v9.f32'; call cut prov, v9, ws, winSec, vw
  ev=envOf(prov, vw, work'/v9a_v9')
  do feed over .array~of('FD','FC')
    fw=work'/v9a_'feed'.f32'
    st=t0+ws
    if st<ch[feed]~startSec | st+winSec>ch[feed]~endSec then do; say sec2hms(t0+ws)~left(12) feed 'no coverage'; iterate; end
    ch[feed]~writeWindow(st,winSec*8000,fw)
    ef=envOf(prov, fw, work'/v9a_'feed)
    /* same wall-clock span; lag L means v9[t] ~ feed[t+L] */
    x=prov~xcorr(ev,ef,-maxLag*100,maxLag*100,1,1)
    sc=x['SCORES']; best=-9; bi=1; s=0; ss=0
    do i=1 to sc~items; v=sc[i]; s+=v; ss+=v*v; if v>best then do; best=v; bi=i; end; end
    k=sc~items; mu=s/k; sd=RxCalcSqrt(max(ss/k-mu*mu,1e-12),16)
    sec=-9; do i=1 to k; if abs(i-bi)>50 & sc[i]>sec then sec=sc[i]; end
    lag=x['LAGS'][bi]/100
    say sec2hms(t0+ws)~left(12) feed~left(4) format(lag,,2)~right(8) format(best,,3)~right(7) format((best-mu)/sd,,1)~right(6) format((sec-mu)/sd,,1)~right(9)
  end
end
exit 0

cut: procedure
  use arg prov, inF, startS, durS, outF
  i=.stream~new(inF); i~open('READ'); data=i~charin(trunc(startS*8000)*4+1, trunc(durS*8000)*4); i~close
  o=.stream~new(outF); o~open('WRITE REPLACE'); o~charout(data); o~close
  return

envOf: procedure
  use arg prov, f, base
  n=.stream~new(f)~query('size')/4
  mask=base'.mask.tsv'; m=.stream~new(mask); m~open('WRITE REPLACE')
  m~lineout('start'||'09'x||'end'||'09'x||'lo'||'09'x||'hi'||'09'x||'w'); m~lineout('0'||'09'x||n||'09'x||'300'||'09'x||'3400'||'09'x||'1'); m~close
  sel=base'.sp.f32'; x=prov~renderSelection(f,mask,sel,8000,256,64)
  e=base'.env.f32'; nb=prov~envelope(sel,e,80,1,300)
  return e

::requires 'FeedChain.cls'
::requires 'AudioV9SpatialNativeProvider.cls'
::requires 'rxmath' LIBRARY
