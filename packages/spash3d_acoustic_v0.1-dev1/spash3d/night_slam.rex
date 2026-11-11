/* night_slam.rex -- voice-profile SLAM decision over FD candidate windows: which voice (or which voices together)
 * each stretch best matches, and the 5-10 s clip to listen to.
 * Architecture: Tom Dyer (6 Nov 2026: night period TP1-TP5; pick the best-match voice including union candidates;
 *   SLAM makes the decision; 5-10 s clips with times).  Coding: Claude (Opus 5.5).
 * 1 Candidates (cheap, native): lifted frames from fd_scan.rex for the given TP files; per profile, stretches
 *   (gaps <= 0.3 s, >= 0.15 s, steady pitch p90/p10 < 1.015 over >= 0.4 s dropped); each opens an 8 s window,
 *   windows merge while overlapping and <= 10 s; score = sum mean contrast x length; best nCand kept.
 * 2 SLAM per candidate: FD window (+1 s each side) -> amp (native speech AGC -20 dBFS, +36 dB max) -> screech
 *   suppression -> enhancer (90-3600 Hz, no tilt: the profiles' shapes were measured untilted) -> native voice
 *   features (YIN 50-500 Hz, 50 ms / 10 ms, 32 bands, the profiles' own settings) -> voiced runs (>= 8 frames,
 *   octave errors removed).  Per run: every profile's run score; runs with median pitch > 420 Hz (cat / not a
 *   voice) or flat pitch (flat fraction >= 0.8: machine tone) are not voices.  Decision for a run = the
 *   best-scoring profile, if that score meets the profile's own strict threshold; else NONE.
 *   Weight of a decided run = length x (1 + min(2, best score - second best score)) (a clear win counts more).
 *   Window decision: profiles by decided seconds; the top one, plus any other with >= 30 % of its seconds and
 *   >= 0.5 s (a conversation: union).  Window score = sum of weights.  Kept when >= 1 s is decided.
 *   Clip: decided runs' span +- 0.75 s, at least 5 s, at most 10 s (centred on the decided runs' weighted middle).
 * Writes outDir/slam_decisions.tsv (all candidates) and outDir/slam_top.tsv (best nTop, no overlaps, time order).
 * usage: night_slam.rex scanDir tpList pcmDir workDir outDir nCand nTop profile [profile ...]
 *   tpList: comma-separated, e.g. tp01,tp02 */
numeric digits 16
parse arg sd tpl pcm w outD nCand nTop profs
prov=.AudioV9SpatialNativeProvider~new(value('AUDIO_V9_VOICE_ROOT',,'ENVIRONMENT')'/run/native/av9_spatial.bridge.json')
ch=fdChainFull(pcm)
profA=.array~new; loop pf over profs~space~makeArray(' '); profA~append(.VoiceProfile~load(pf)); end
/* ---- 1 candidates ---- */
winList=.array~new
loop vp over profA
  lab=vp~label
  loop tp over tpl~makeArray(',')
    f=sd'/'tp'_'lab'.lifted.tsv'; if stream(f,'C','QUERY EXISTS')='' then iterate
    s=.stream~new(f); s~open('READ'); cur=.nil
    do while s~lines>0
      parse value s~linein with t '09'x f0 '09'x con
      if cur<>.nil then if t-cur['B']<=0.3 then do; cur['B']=t; cur['C']+=con; cur['N']+=1; cur['F']~append(f0+0); iterate; end
      if cur<>.nil then call closeStretch
      cur=.directory~new; cur['A']=t; cur['B']=t; cur['C']=con; cur['N']=1; cur['F']=.array~of(f0+0)
    end
    s~close; if cur<>.nil then call closeStretch
  end
end
winList=winList~sort; merged=.array~new
loop wv over winList
  parse var wv a b sc; a=a+0
  if merged~items>0 then do
    parse value merged[merged~items] with ma mb msc
    if a<=mb & max(mb,b)-ma<=10 then do; merged[merged~items]=ma max(mb,b) (msc+sc); iterate; end
  end
  merged~append(a b sc)
end
cand=.array~new; loop mv over merged; parse var mv a b sc; cand~append(right(format(sc,,4),14,'0')||'|'||a||'|'||b); end
cand=cand~sortWith(.DescendingComparator~new)
say merged~items 'candidate windows; SLAM on the best' min(nCand,cand~items)
/* ---- 2 SLAM ---- */
dec=.stream~new(outD'/slam_decisions.tsv'); dec~open('WRITE REPLACE')
dec~lineout('cand'||'09'x||'win_from'||'09'x||'win_to'||'09'x||'clip_from'||'09'x||'clip_s'||'09'x||'decision'||'09'x||'score'||'09'x||'decided_s'||'09'x||'runs'||'09'x||'by_profile_s')
keepers=.array~new; ci=0
loop c over cand
  ci+=1; if ci>nCand then leave
  parse var c . '|' a '|' b
  a=a+0; b=b+0; w0=a-1; n=trunc((b-a+2)*8000)
  x=ch~writeWindow(w0,n,w'/ns_raw.f32')
  x=prov~speechAgc(w'/ns_raw.f32',w'/ns_amp.f32',8000,-20,36,10,400,6,-1)
  nb=prov~suppressTonalBursts(w'/ns_amp.f32',w'/ns_scr.f32',w'/ns_screech.tsv')
  x=prov~enhance(w'/ns_scr.f32',w'/ns_enh.f32',8000,256,64,1.5,0.98,1.0,0.1,90,3600)
  vf=w'/ns_'ci'.vf.tsv'; nf=prov~voiceFeatures(w'/ns_enh.f32',vf,8000,400,80,50,500,0.25,32)
  fr=.VoiceProfile~voicedFrames(vf); rs=.VoiceProfile~runsOf(fr,8); .VoiceProfile~cache~remove(vf); call sysFileDelete vf
  dsec=.directory~new; wsum=.directory~new; tot=0; dtot=0; nRuns=0; spanA=9e9; spanB=-9e9; mid=0
  loop r over rs
    fz=.array~new; loop fx over r; fz~append(fx['F0']); end; fz=fz~sortWith(.NumericComparator~new); med=fz[(fz~items+1)%2]
    if med>420 then iterate
    if flatFraction(r)>=0.8 then iterate
    best=''; bs=-9e9; s2=-9e9
    loop vp over profA
      sc=vp~runScore(r)
      if sc>bs then do; s2=bs; bs=sc; bp=vp; end; else if sc>s2 then s2=sc
    end
    nRuns+=1
    if bs<bp~threshold then iterate
    ra=r[1]['T']; rb=r[r~items]['T']; len=rb-ra+0.05; lab=bp~label~changestr('VOICE_','')
    wt=len*(1+min(2,bs-s2))
    if \dsec~hasIndex(lab) then do; dsec[lab]=0; wsum[lab]=0; end
    dsec[lab]+=len; wsum[lab]+=wt; tot+=wt; dtot+=len; mid+=wt*(ra+rb)/2
    spanA=min(spanA,ra); spanB=max(spanB,rb)
  end
  if dtot<1 then do; dec~lineout(ci'09'x||sec2hms(a)'09'x||sec2hms(b)'09'x||'-'||'09'x||'-'||'09'x||'NONE'||'09'x||format(tot,,2)'09'x||format(dtot,,2)'09'x||nRuns'09'x||'-'); iterate; end
  ord=.array~new; loop k over dsec~allIndexes; ord~append(right(format(dsec[k],,3),10,'0')'|'k); end
  ord=ord~sortWith(.DescendingComparator~new)
  parse value ord[1] with top '|' l1; decision=l1; byp=''
  loop o over ord; parse var o ds '|' lb; byp=byp||lb':'format(ds,,1)' '; end
  loop i=2 to min(3,ord~items); parse value ord[i] with ds '|' lb; if ds>=0.3*top & ds>=0.5 then decision=decision'+'lb; end
  cm=mid/tot; ca=spanA-0.75; cb=spanB+0.75
  if cb-ca<5 then do; ca=cm-2.5; cb=cm+2.5; end
  if cb-ca>10 then do; ca=cm-5; cb=cm+5; end
  ca=w0+ca
  dec~lineout(ci'09'x||sec2hms(a)'09'x||sec2hms(b)'09'x||sec2hms(ca)'09'x||format(cb-(ca-w0),,1)'09'x||decision'09'x||format(tot,,2)'09'x||format(dtot,,2)'09'x||nRuns'09'x||byp~strip)
  keepers~append(right(format(tot,,3),12,'0')'|'ca'|'format(cb-(ca-w0),,2)'|'decision'|'byp~strip'|'format(dtot,,2))
end
dec~close
/* ---- best nTop, no overlaps, time order ---- */
keepers=keepers~sortWith(.DescendingComparator~new); top=.array~new
loop k over keepers
  parse var k sc '|' ca '|' cl '|' decision '|' byp '|' dt
  clash=.false; loop t over top; parse var t . '|' ta '|' tl '|' .; if ca<ta+tl & ca+cl>ta then clash=.true; end
  if \clash then top~append(sc'|'ca'|'cl'|'decision'|'byp'|'dt)
  if top~items>=nTop then leave
end
srt=.array~new; loop t over top; parse var t sc '|' ca '|' rest; srt~append(right(format(ca,,3),12,'0')'|'sc'|'rest); end
srt=srt~sort
o=.stream~new(outD'/slam_top.tsv'); o~open('WRITE REPLACE')
o~lineout('NN'||'09'x||'fd_time'||'09'x||'length_s'||'09'x||'decision'||'09'x||'slam_score'||'09'x||'decided_s'||'09'x||'by_profile_s')
nn=0
loop t over srt
  parse var t ca '|' sc '|' cl '|' decision '|' byp '|' dt; nn+=1
  o~lineout('N'right(nn,2,'0')'09'x||sec2hms(ca+0)'09'x||format(cl,,1)'09'x||decision'09'x||format(sc,,2)'09'x||dt'09'x||byp)
end
o~close
say keepers~items 'candidates decided; top' nn 'written to' outD'/slam_top.tsv'
exit 0
closeStretch:
  if cur['B']-cur['A']<0.15 then return
  if cur['B']-cur['A']>=0.4 then do
    fz=cur['F']~sortWith(.NumericComparator~new); q10=fz[max(1,trunc(fz~items*0.1))]; q90=fz[max(1,trunc(fz~items*0.9))]
    if q90/q10<1.015 then return
  end
  cc=(cur['A']+cur['B'])/2; wa=cc-4; wb=cc+4
  winList~append(right(format(wa,,3),12,'0') format(wb,,3) (cur['C']/cur['N'])*(cur['B']-cur['A']))
  return
/* fraction of frames whose pitch, with the previous 5 frames, spans less than 0.2 semitones (queue window,
   Tom's method; as v7_voice_scan.rex) */
flatFraction: procedure
  use arg run
  recent=.queue~new; flat=0; judged=0
  loop fr over run
    if recent~items=5 then do
      lo=fr['F0']; hi=fr['F0']
      loop prev over recent; lo=min(lo,prev); hi=max(hi,prev); end
      judged+=1; if 12*RxCalcLog(hi/lo,16)/RxCalcLog(2,16)<0.2 then flat+=1
    end
    recent~queue(fr['F0']); if recent~items>5 then recent~pull
  end
  if judged=0 then return 0
  return flat/judged
::requires 'FdChain.cls'
::requires 'VoiceProfile.cls'
::requires 'AudioV9SpatialNativeProvider.cls'
::requires 'rxmath' LIBRARY
