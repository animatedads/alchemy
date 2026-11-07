/* voice_set_build.rex -- build neutral-label voice profiles from a sample set and test strictness.
 * Architecture: Tom Dyer (voice-profile SLAM, 5 Nov 2026).  Coding: Claude (Opus 5.5).
 * manifest TSV lines: label<TAB>features.tsv<TAB>start_s<TAB>end_s     (one line per voice span)
 * 1. Cross-check (strictness): each span split at its middle; profiles built on one half of every voice,
 *    every voiced run of the other halves scored against all profiles; both directions.  Prints a
 *    confusion table true label -> decision (a profile label or NONE).
 * 2. Final profiles on the whole spans, saved as <outDir>/<label>.profile (statistics only).
 * usage: voice_set_build.rex manifest outDir strictPct minRun */
numeric digits 16
parse arg man outDir strictPct minRun .
if strictPct='' then strictPct=10; if minRun='' then minRun=8
v=.array~new; s=.stream~new(man); s~open('READ')
do while s~lines>0
  l=s~linein; if l='' | l~left(1)='#' then iterate
  parse var l lab '09'x f '09'x t0 '09'x t1
  d=.directory~new; d['LABEL']=lab; d['FILE']=f; d['START']=t0+0; d['END']=t1+0; v~append(d)
end
s~close
conf=.directory~new
do dir=1 to 2
  profs=.array~new; tests=.array~new
  do d over v
    mid=(d['START']+d['END'])/2
    tr=.directory~new; tr['FILE']=d['FILE']; te=.directory~new; te['FILE']=d['FILE']
    if dir=1 then do; tr['START']=d['START']; tr['END']=mid; te['START']=mid; te['END']=d['END']; end
    else do; tr['START']=mid; tr['END']=d['END']; te['START']=d['START']; te['END']=mid; end
    p=.VoiceProfile~new(d['LABEL'])
    if buildSafe(p, .array~of(tr), strictPct, minRun)<0 then say 'direction' dir d['LABEL'] 'half too thin for a profile (under 50 voiced frames): not built, its other half is still tested'
    else profs~append(p)
    te['LABEL']=d['LABEL']; tests~append(te)
  end
  do te over tests
    fr=.VoiceProfile~voicedFrames(te['FILE'],te['START'],te['END']); rs=.VoiceProfile~runsOf(fr,minRun)
    do r over rs
      best='NONE'; bs=-9e9
      do p over profs; sc=p~runScore(r); if sc>=p~threshold & sc>bs then do; bs=sc; best=p~label; end; end
      k=te['LABEL']||' -> '||best; if conf~hasIndex(k) then conf[k]=conf[k]+1; else conf[k]=1
    end
  end
end
say 'held-out half runs, both directions (true -> decision):'
do k over conf~allIndexes~sort; say '  ' k~left(26) conf[k]; end
do d over v
  p=.VoiceProfile~new(d['LABEL'])
  n=buildSafe(p, .array~of(d), strictPct, minRun)
  if n<0 then do; say d['LABEL'] 'too thin for a profile'; iterate; end
  p~save(outDir'/'d['LABEL']'.profile')
  say d['LABEL'] 'profile:' n 'runs,' p~frames 'voiced frames, pitch window' p~window 'Hz, threshold' format(p~threshold,,3)
end
exit 0
buildSafe: procedure
  use arg p, segs, strictPct, minRun
  signal on syntax name failed
  return p~build(segs, strictPct, minRun)
failed:
  return -1
::requires 'VoiceProfile.cls'
