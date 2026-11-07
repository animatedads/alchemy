/* fd_place.rex -- place each FC moment on the FD chain (TP6-TP9 originals) and measure the FD/FC lag.
 * Architecture: Tom Dyer (5 Nov 2026: FD originals TP6-TP9 for the moments).  Coding: Claude (Opus 5.5).
 * FD chain: TP7 at its filename time 11:14:49 (the anchor the clock was fitted on, 31 Oct), TP8 and TP9 each
 * at the previous end + 0.08 s seam, TP6 ending 0.08 s before TP7 starts.
 * Per moment: the whole V7 clip (FC, channel 1) against the FD window at the clock prediction
 * FC - FD = 0.9065 + 0.1331 h; speech-band (300-3400 Hz) native envelopes, 10 ms bins, lag search +-maxLag s.
 * The lag is used when z >= zMin; otherwise the clock prediction stands (flagged CLOCK).
 * Writes outDir/fd_place.tsv: NN fc_time fd_time offset_s source z clockpred_s lag_s.
 * usage: fd_place.rex momentsIndex clipStartTsv workDir pcmDir outDir maxLag zMin */
numeric digits 16
parse arg mix cst w pcm outD maxLag zMin
prov=.AudioV9SpatialNativeProvider~new(value('AUDIO_V9_VOICE_ROOT',,'ENVIRONMENT')'/run/native/av9_spatial.bridge.json')
fd=.FeedChain~new('FD'); seam=0.08
t7=hms2sec('111449'); d6=stream(pcm'/tp06.f32','C','QUERY SIZE')/4/8000
prev=fd~add(pcm'/tp06.f32',t7-seam-d6)
prev=fd~add(pcm'/tp07.f32',t7)
prev=fd~add(pcm'/tp08.f32',prev['END']+seam)
prev=fd~add(pcm'/tp09.f32',prev['END']+seam)
say 'FD chain' sec2hms(fd~startSec) '-' sec2hms(fd~endSec)
starts=.directory~new; s=.stream~new(cst); s~open('READ')
do while s~lines>0; parse value s~linein with nm '09'x st; starts[nm~changestr('.ogg','')]=st; end
s~close
o=.stream~new(outD'/fd_place.tsv'); o~open('WRITE REPLACE')
o~lineout('NN'||'09'x||'fc_time'||'09'x||'fd_time'||'09'x||'offset_s'||'09'x||'source'||'09'x||'z'||'09'x||'clockpred_s'||'09'x||'lag_s')
m=.stream~new(mix); m~open('READ'); h=m~linein
do while m~lines>0
  parse value m~linein with nn '09'x fct '09'x clip '09'x a '09'x len '09'x .
  id=clip; tClip=starts[id]+28800; tMom=tClip+a
  hh=(tMom-12*3600)/3600; pred=0.9065+0.1331*hh
  fcF=w'/'id'_ch1.f32'; clipS=stream(fcF,'C','QUERY SIZE')/4/8000
  if tClip-pred<fd~startSec | tClip-pred+clipS>fd~endSec then do
    o~lineout(nn'09'x||fct'09'x||'-'||'09'x||'-'||'09'x||'NO_FD'||'09'x||'-'||'09'x||format(pred,,3)||'09'x||'-'); iterate
  end
  fdW=w'/fp_fd.f32'; x=fd~writeWindow(tClip-pred,trunc(clipS*8000),fdW)
  ev=envOf(prov,fcF,w'/fp_fc'); ef=envOf(prov,fdW,w'/fp_fd')
  x=prov~xcorr(ev,ef,-maxLag*100,maxLag*100,1,1)
  sc=x['SCORES']; best=-9; bi=1; sm=0; ss=0
  loop i=1 to sc~items; v=sc[i]; sm+=v; ss+=v*v; if v>best then do; best=v; bi=i; end; end
  k=sc~items; mu=sm/k; sd=RxCalcSqrt(max(ss/k-mu*mu,1e-12),16); z=(best-mu)/sd
  lag=x['LAGS'][bi]/100
  if z>=zMin then do; off=pred-lag; src='MEASURED'; end; else do; off=pred; src='CLOCK'; end
  o~lineout(nn'09'x||fct'09'x||sec2hms(tMom-off)'09'x||format(off,,3)'09'x||src'09'x||format(z,,1)'09'x||format(pred,,3)'09'x||format(lag,,2))
end
m~close; o~close
say 'written' outD'/fd_place.tsv'
exit 0
envOf: procedure
  use arg prov, f, base
  n=stream(f,'C','QUERY SIZE')/4
  mask=base'.mask.tsv'; mk=.stream~new(mask); mk~open('WRITE REPLACE')
  mk~lineout('start'||'09'x||'end'||'09'x||'lo'||'09'x||'hi'||'09'x||'w'); mk~lineout('0'||'09'x||n||'09'x||'300'||'09'x||'3400'||'09'x||'1'); mk~close
  sel=base'.sp.f32'; x=prov~renderSelection(f,mask,sel,8000,256,64)
  e=base'.env.f32'; nb=prov~envelope(sel,e,80,1,300)
  return e
::requires 'FeedChain.cls'
::requires 'AudioV9SpatialNativeProvider.cls'
::requires 'rxmath' LIBRARY
