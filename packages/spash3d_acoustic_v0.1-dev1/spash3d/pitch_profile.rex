/* pitch_profile.rex -- male / female pitch profiles in small buckets from clean reference speech.
 * Architecture: Tom Dyer (5 Nov 2026: many small buckets, separate male and female profiles, because the
 *   conversations overlap; build from clean broadcast samples with the right accent).  Coding: Claude (Opus 5.5).
 * Input: YIN TSVs (time_s f0_hz aperiodicity rms_db) from the native tracker.
 * 1. Voiced runs: consecutive voiced frames (gaps of 1 frame bridged), >= minRun frames.  Frames more than
 *    0.6 octave from their run's median are dropped (octave errors).
 * 2. Split: histogram of run-median log2(F0) in 1/24-octave buckets, smoothed (5 buckets); male peak in
 *    80-150 Hz, female peak in 155-300 Hz; the lowest point between the two peaks separates the modes.  Runs below = M, above = F.
 * 3. Profiles: per class, frame counts per 1/24-octave bucket from 60 to 500 Hz, probability, and the
 *    per-bucket posterior P(F | bucket) with equal priors; percentile windows p5..p95; within-run range.
 * Outputs (outPrefix): _buckets.tsv, _windows.tsv, _runs.tsv
 * usage: pitch_profile.rex outPrefix minRunFrames yin1.tsv [yin2.tsv ...]
 */
numeric digits 16
parse arg outP minRun files
lo=60; hi=500; bpo=24
nb=trunc(bpo*RxCalcLog(hi/lo,16)/RxCalcLog(2,16))+1
runs=.array~new
do f over files~space~makeArray(' ')
  s=.stream~new(f); s~open('READ'); h=s~linein; cur=.array~new; gap=0
  do while s~lines>0
    parse value s~linein with t '09'x f0 '09'x ap '09'x db
    if f0>0 then do; cur~append(f0+0); gap=0; end
    else do
      gap+=1
      if gap>1 then do; if cur~items>=minRun then runs~append(cleanRun(cur,filespec('name',f),t)); cur=.array~new; end
    end
  end
  if cur~items>=minRun then runs~append(cleanRun(cur,filespec('name',f),t))
  s~close
end
/* split by valley of run-median histogram */
hist=.array~new(nb); do i=1 to nb; hist[i]=0; end
do r over runs; b=bucketOf(r['MED']); if b>0 then hist[b]=hist[b]+1; end
sm=.array~new(nb); do i=1 to nb; a=0; c=0; do j=max(1,i-2) to min(nb,i+2); a+=hist[j]; c+=1; end; sm[i]=a/c; end
/* male peak in 80-150 Hz, female peak in 155-300 Hz, valley = lowest smoothed point between the two peaks */
pM=bucketOf(80); do i=bucketOf(80) to bucketOf(150); if sm[i]>sm[pM] then pM=i; end
pF=bucketOf(155); do i=bucketOf(155) to bucketOf(300); if sm[i]>sm[pF] then pF=i; end
valley=pM; vv=9e9
do i=pM to pF; if sm[i]<vv then do; vv=sm[i]; valley=i; end; end
say 'male peak' format(centre(pM),,1) 'Hz, female peak' format(centre(pF),,1) 'Hz, valley' format(centre(valley),,1) 'Hz'
split=edge(valley+1)   /* upper edge of the valley bucket */
cntM=.array~new(nb); cntF=.array~new(nb); do i=1 to nb; cntM[i]=0; cntF[i]=0; end
fm=.array~new; ff=.array~new; rgM=.array~new; rgF=.array~new; nM=0; nF=0
o=.stream~new(outP'_runs.tsv'); o~open('WRITE REPLACE'); o~lineout('source'||'09'x||'end_s'||'09'x||'frames'||'09'x||'median_hz'||'09'x||'range_semitones'||'09'x||'class')
do r over runs
  k='F'; if r['MED']<split then k='M'
  if k='M' then nM+=1; else nF+=1
  do v over r['F']; b=bucketOf(v); if b<1 then iterate
    if k='M' then do; cntM[b]=cntM[b]+1; fm~append(v); end; else do; cntF[b]=cntF[b]+1; ff~append(v); end
  end
  if k='M' then rgM~append(r['RANGE']); else rgF~append(r['RANGE'])
  o~lineout(r['SRC']'09'x||r['END']'09'x||r['F']~items'09'x||format(r['MED'],,1)'09'x||format(r['RANGE'],,1)'09'x||k)
end
o~close
tM=fm~items; tF=ff~items
o=.stream~new(outP'_buckets.tsv'); o~open('WRITE REPLACE')
o~lineout('bucket'||'09'x||'lo_hz'||'09'x||'hi_hz'||'09'x||'centre_hz'||'09'x||'male_frames'||'09'x||'female_frames'||'09'x||'p_male'||'09'x||'p_female'||'09'x||'posterior_female')
do i=1 to nb
  pm=cntM[i]/max(tM,1); pf=cntF[i]/max(tF,1); post='NA'; if pm+pf>0 then post=format(pf/(pm+pf),,3)
  o~lineout(i'09'x||format(edge(i),,1)'09'x||format(edge(i+1),,1)'09'x||format(centre(i),,1)'09'x||cntM[i]'09'x||cntF[i]'09'x||format(pm,,4)'09'x||format(pf,,4)'09'x||post)
end
o~close
o=.stream~new(outP'_windows.tsv'); o~open('WRITE REPLACE')
o~lineout('class'||'09'x||'runs'||'09'x||'frames'||'09'x||'p5'||'09'x||'p10'||'09'x||'p25'||'09'x||'p50'||'09'x||'p75'||'09'x||'p90'||'09'x||'p95'||'09'x||'run_range_semitones_median')
o~lineout('M'||'09'x||nM'09'x||tM'09'x||pct(fm,5)'09'x||pct(fm,10)'09'x||pct(fm,25)'09'x||pct(fm,50)'09'x||pct(fm,75)'09'x||pct(fm,90)'09'x||pct(fm,95)'09'x||pct(rgM,50))
o~lineout('F'||'09'x||nF'09'x||tF'09'x||pct(ff,5)'09'x||pct(ff,10)'09'x||pct(ff,25)'09'x||pct(ff,50)'09'x||pct(ff,75)'09'x||pct(ff,90)'09'x||pct(ff,95)'09'x||pct(rgF,50))
o~lineout('SPLIT_HZ'||'09'x||format(split,,1))
o~close
say 'runs' runs~items '(M' nM', F' nF')  split' format(split,,1) 'Hz  frames M' tM 'F' tF
exit 0
cleanRun: procedure
  use arg a, src, t
  s=a~copy~sortWith(.NumericComparator~new); med=s[(s~items+1)%2]
  keep=.array~new; do v over a; if abs(RxCalcLog(v/med,16)/RxCalcLog(2,16))<=0.6 then keep~append(v); end
  s=keep~copy~sortWith(.NumericComparator~new); med=s[(s~items+1)%2]
  p10=s[max(1,trunc(s~items*0.1))]; p90=s[max(1,trunc(s~items*0.9))]
  d=.directory~new; d['F']=keep; d['MED']=med; d['SRC']=src; d['END']=t
  d['RANGE']=12*RxCalcLog(p90/p10,16)/RxCalcLog(2,16)
  return d
bucketOf: procedure expose lo bpo nb
  use arg f
  if f<lo then return 0
  b=trunc(bpo*RxCalcLog(f/lo,16)/RxCalcLog(2,16))+1
  if b>nb then return 0
  return b
edge: procedure expose lo bpo
  use arg i; return lo*RxCalcPower(2,(i-1)/bpo,16)
centre: procedure expose lo bpo
  use arg i; return lo*RxCalcPower(2,(i-0.5)/bpo,16)
pct: procedure
  use arg a, p
  if a~items=0 then return 'NA'
  s=a~copy~sortWith(.NumericComparator~new); return format(s[max(1,trunc(s~items*p/100))],,1)
::requires 'rxmath' LIBRARY
