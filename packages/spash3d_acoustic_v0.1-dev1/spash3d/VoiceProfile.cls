/* VoiceProfile.cls -- voice-type profiles and strict matching (voice-profile SLAM).
 * Architecture: Tom Dyer (5 Nov 2026): one profile per sample voice, not a collective; match strictly, only a
 *   voice like that one; profiles carry neutral labels (VOICE_M1, VOICE_F2 ...); the samples and any names are
 *   deleted after the profile is built.  Coding: Claude (Opus 5.5).
 * Features come from the native voiceFeatures TSV: time_s f0_hz aperiodicity rms_db s1..sN (spectral shape, dB).
 * A profile holds:
 *   pitch   -- frame counts in 1/24-octave buckets 60-500 Hz, smoothed over +-1 bucket, with a floor
 *   shape   -- per band mean and standard deviation of the spectral shape over voiced frames
 *   window  -- the voice's own run scores (mean frame log-likelihood per voiced run); a run of new audio is
 *              accepted only if it scores at or above the profile's own p<strict> run score ("strictly").
 * Frame log-likelihood = log P(pitch bucket) + (-0.5 * mean over bands of z^2)   (both natural-log scale).
 */
::class VoiceProfile public
::attribute label get
::attribute frames get
::attribute threshold get
::attribute pitch get
::attribute mu get
::attribute sd get
::attribute nb get
::attribute winLo get
::attribute winHi get
::constant LO 60
::constant BPO 24
::constant NBUCK 67

::method init
  expose label frames threshold pitch mu sd nb winLo winHi
  use strict arg label, nb=32
  winLo=60; winHi=500; frames=0; threshold=-9e9; pitch=.array~new; mu=.array~new; sd=.array~new

/* build from an array of directories: FILE (features TSV), START, END (seconds) */
::method build
  expose label frames threshold pitch mu sd nb winLo winHi
  use strict arg segs, strictPct=10, minRun=10
  cnt=.array~new; do i=1 to self~NBUCK; cnt[i]=0; end
  sum=.array~new; sq=.array~new; do b=1 to nb; sum[b]=0; sq[b]=0; end
  runs=.array~new; f0s=.array~new
  do sg over segs
    fr=.VoiceProfile~voicedFrames(sg['FILE'], sg['START'], sg['END'])
    do r over .VoiceProfile~runsOf(fr, minRun)
      runs~append(r)
      do f over r
        k=.VoiceProfile~bucket(f['F0']); if k>0 then cnt[k]=cnt[k]+1
        f0s~append(f['F0'])
        do b=1 to nb; v=f['S'][b]; sum[b]+=v; sq[b]+=v*v; end
        frames+=1
      end
    end
  end
  if frames<50 then raise syntax 88.900 array('too few voiced frames for a profile',label,frames)
  /* the voice's own pitch window: p5..p95 of its voiced frames (raw, no smoothing or floor) */
  f0s=f0s~sortWith(.NumericComparator~new); winLo=f0s[max(1,trunc(f0s~items*0.05))]; winHi=f0s[max(1,trunc(f0s~items*0.95))]
  tot=0; do i=1 to self~NBUCK; tot+=cnt[i]; end
  do i=1 to self~NBUCK
    a=0; do j=max(1,i-1) to min(self~NBUCK,i+1); w=1; if j=i then w=2; a+=w*cnt[j]; end
    pitch[i]=max(a/(4*tot), 1e-4)
  end
  do b=1 to nb
    mu[b]=sum[b]/frames; v=sq[b]/frames-mu[b]*mu[b]; sd[b]=max(RxCalcSqrt(max(v,0),16),1.0)
  end
  sc=.array~new; do r over runs; sc~append(self~runScore(r)); end
  sc=sc~sortWith(.NumericComparator~new)
  threshold=sc[max(1,trunc(sc~items*strictPct/100))]
  return runs~items

::method frameScore
  expose pitch mu sd nb
  use strict arg f
  k=.VoiceProfile~bucket(f['F0']); if k<1 then return -50
  z=0; do b=1 to nb; q=(f['S'][b]-mu[b])/sd[b]; z+=q*q; end
  return RxCalcLog(pitch[k],16) - 0.5*z/nb

::method runScore
  use strict arg run
  s=0; do f over run; s+=self~frameScore(f); end
  return s/run~items


/* pitch probability that pct % of the voice's own frames are at or below (typicality floor) */
::method pitchFloor
  expose pitch
  use strict arg pct=20
  a=pitch~copy~sortWith(.NumericComparator~new); tot=0; do v over a; tot+=v; end
  c=0; do v over a; c+=v; if c/tot>=pct/100 then return v; end
  return a[1]
/* pitch window: p5..p95 of the voice's own voiced frames (stored at build time) */
::method window
  expose winLo winHi
  return format(winLo,,1) format(winHi,,1)
/* profile spectral shape as hz<TAB>linear gain (max 1), band centres 100-3800 Hz log-spaced */
::method writeShape
  expose mu nb
  use strict arg path
  mx=-999; do v over mu; mx=max(mx,v); end
  o=.stream~new(path); o~open('WRITE REPLACE')
  do b=1 to nb
    hz=100*RxCalcPower(3800/100,(b-0.5)/nb,16)
    o~lineout(format(hz,,1)'09'x||format(RxCalcPower(10,(mu[b]-mx)/20,16),,4))
  end
  o~close
  return path
/* ---- persistence: neutral label and statistics only ---- */
::method save
  expose label frames threshold pitch mu sd nb winLo winHi
  use strict arg path
  o=.stream~new(path); o~open('WRITE REPLACE')
  o~lineout('VOICE_PROFILE/2'||'09'x||label||'09'x||frames||'09'x||threshold||'09'x||nb||'09'x||winLo||'09'x||winHi)
  l='PITCH'; do v over pitch; l=l||'09'x||v; end; o~lineout(l)
  l='MU'; do v over mu; l=l||'09'x||v; end; o~lineout(l)
  l='SD'; do v over sd; l=l||'09'x||v; end; o~lineout(l)
  o~close
::method load class
  use strict arg path
  s=.stream~new(path); s~open('READ')
  h=s~linein~makeArray('09'x); p=self~new(h[2], h[5])
  do 3; l=s~linein~makeArray('09'x); a=.array~new; do i=2 to l~items; a~append(l[i]+0); end
    select; when l[1]='PITCH' then p~setPitch(a); when l[1]='MU' then p~setMu(a); otherwise p~setSd(a); end
  end
  s~close; p~setMeta(h[3], h[4]); if h~items>=7 then p~setWindow(h[6]+0, h[7]+0); return p
::method setPitch; expose pitch; use arg pitch
::method setMu; expose mu; use arg mu
::method setSd; expose sd; use arg sd
::method setMeta; expose frames threshold; use arg frames, threshold
::method setWindow; expose winLo winHi; use arg winLo, winHi

/* ---- shared helpers ---- */
::method bucket class
  use arg f
  if f<self~LO then return 0
  k=trunc(self~BPO*RxCalcLog(f/self~LO,16)/RxCalcLog(2,16))+1
  if k>self~NBUCK then return 0
  return k
/* voiced frames in [start,end): f0>0, aperiodicity<=0.25, rms within 25 dB of the slice's loudest frame.
   Each features file is parsed once and cached; slices are cut by frame index (fixed hop). */
::method voicedFrames class
  use strict arg path, t0=0, t1=1e9
  c=.VoiceProfile~cache
  if \c~hasIndex(path) then do
    s=.stream~new(path); s~open('READ'); h=s~linein; all=.array~new
    do while s~lines>0
      l=s~linein~makeArray('09'x)
      d=.directory~new; d['T']=l[1]+0; d['F0']=l[2]+0; d['AP']=l[3]+0; d['DB']=l[4]+0
      sh=.array~new; do i=5 to l~items; sh~append(l[i]+0); end; d['S']=sh
      all~append(d)
    end
    s~close; c[path]=all
  end
  all=c[path]; if all~items<2 then return .array~new
  first=all[1]['T']; hopS=all[2]['T']-first
  i0=max(1,trunc((t0-first)/hopS)+1); i1=min(all~items,trunc((min(t1,1e8)-first)/hopS)+1)
  sl=.array~new; mx=-200
  do i=i0 to i1; d=all[i]; if d['T']<t0 | d['T']>=t1 then iterate; sl~append(d); if d['DB']>mx then mx=d['DB']; end
  out=.array~new
  do d over sl; e=d~copy; e['V']=(d['F0']>0 & d['AP']<=0.25 & d['DB']>=mx-25); out~append(e); end
  return out
::attribute cache class get
::method init class
  expose cache
  forward class (super) continue
  cache=.directory~new
/* voiced runs: consecutive voiced frames, 1-frame gaps bridged, at least minRun frames.  Octave errors removed
   per run: frames more than 0.6 octave from the run's median F0, and frames at the tracker ceiling (>= 495 Hz). */
::method runsOf class
  use strict arg all, minRun=10
  runs=.array~new; cur=.array~new; gap=0
  do d over all
    if d['V'] then do; cur~append(d); gap=0; end
    else do; gap+=1; if gap>1 then do; call keepRun runs, cur, minRun; cur=.array~new; end; end
  end
  call keepRun runs, cur, minRun
  return runs
keepRun: procedure
  use arg runs, cur, minRun
  ok=.array~new; do d over cur; if d['F0']<495 then ok~append(d); end
  if ok~items<minRun then return
  s=.array~new; do d over ok; s~append(d['F0']); end; s=s~sortWith(.NumericComparator~new); med=s[(s~items+1)%2]
  k=.array~new; do d over ok; if abs(RxCalcLog(d['F0']/med,16)/RxCalcLog(2,16))<=0.6 then k~append(d); end
  if k~items>=minRun then runs~append(k)
  return
::requires 'rxmath' LIBRARY
