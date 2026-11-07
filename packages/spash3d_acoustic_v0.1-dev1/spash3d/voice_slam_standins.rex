/* voice_slam_standins.rex -- validation of the voice-profile SLAM before real samples arrive.
 * Architecture: Tom Dyer.  Coding: Claude (Opus 5.5), 5 Nov 2026.
 * Stand-in "voices": the male and female pitch classes of the two TV clips (tv_runs.tsv), neutral labels
 * VOICE_SM (stand-in male) and VOICE_SF (stand-in female).  Every 3rd run is held out for testing.
 * Reports: per held-out run, which profile accepts it (strictly) -> confusion table; false accepts on poi1
 * (a male voice not in the training set, phone channel) are reported separately.
 * usage: voice_slam_standins.rex runsTsv featDir outDir strictPct */
numeric digits 16
parse arg runsF featDir outDir strictPct .
if strictPct='' then strictPct=10
tr=.directory~new; te=.array~new; tr['M']=.array~new; tr['F']=.array~new
s=.stream~new(runsF); s~open('READ'); h=s~linein; i=0
do while s~lines>0
  c=s~linein~makeArray('09'x); if c~items<6 then iterate; i+=1
  src=featDir'/'c[1]~changestr('.yin.tsv','.vf.tsv'); t1=c[2]+0.03; t0=t1-(c[3]+2)*0.01-0.04
  d=.directory~new; d['FILE']=src; d['START']=t0; d['END']=t1; d['CLASS']=c[6]
  if i//3=0 then te~append(d); else tr[c[6]]~append(d)
end
s~close
profs=.array~new
do k over .array~of('M','F')
  p=.VoiceProfile~new('VOICE_S'k); nr=p~build(tr[k],strictPct); p~save(outDir'/VOICE_S'k'.profile')
  say p~label 'trained on' nr 'runs,' p~frames 'frames; own-window threshold' format(p~threshold,,3)
  profs~append(p)
end
conf=.directory~new
do t over te
  fr=.VoiceProfile~voicedFrames(t['FILE'],t['START'],t['END']); rs=.VoiceProfile~runsOf(fr,5)
  if rs~items=0 then do; call tally conf, t['CLASS'], 'NO_VOICED'; iterate; end
  r=rs[1]; do q over rs; if q~items>r~items then r=q; end
  call tally conf, t['CLASS'], decide(profs, r)
end
say 'held-out runs (true class -> decision):'
do k over conf~allIndexes~sort; say '  ' k~left(22) conf[k]; end
fr=.VoiceProfile~voicedFrames(featDir'/poi1.vf.tsv'); rs=.VoiceProfile~runsOf(fr,5); pc=.directory~new
do r over rs; call tally pc, 'poi1(male,phone)', decide(profs, r); end
do k over pc~allIndexes; say '  ' k~left(30) pc[k]; end
exit 0
decide: procedure
  use arg profs, r
  best='NONE'; bs=-9e9
  do p over profs; sc=p~runScore(r); if sc>=p~threshold & sc>bs then do; bs=sc; best=p~label; end; end
  return best
tally: procedure
  use arg dir, a, b
  k=a||'->'||b; if dir~hasIndex(k) then dir[k]=dir[k]+1; else dir[k]=1
  return
::requires 'VoiceProfile.cls'
