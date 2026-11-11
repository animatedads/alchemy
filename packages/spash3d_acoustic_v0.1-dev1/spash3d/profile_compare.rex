/* profile_compare.rex -- how does one voice profile sit against the others?
 * Architecture: Tom Dyer.  Coding: Claude (Opus 5.5), 5 Nov 2026.
 * For the target profile T (built from its own segment list here so its runs are available):
 *   - pitch windows (p5-p95) of every profile and their overlap with T's, in semitones
 *   - timbre distance: RMS over bands of (mu_T - mu_P) / pooled sd   (0 = identical average spectrum)
 *   - T's own voiced runs scored by every profile: mean score and how many each profile would ACCEPT
 * usage: profile_compare.rex label features.tsv start end minRun profile [profile ...] */
numeric digits 16
parse arg lab vf t0 t1 minRun profs
seg=.directory~new; seg['FILE']=vf; seg['START']=t0; seg['END']=t1
T=.VoiceProfile~new(lab); n=T~build(.array~of(seg),10,minRun)
T~save(value('VOICE_OUT',,'ENVIRONMENT')'/'lab'.profile')
fr=.VoiceProfile~voicedFrames(vf,t0,t1); runsT=.VoiceProfile~runsOf(fr,minRun)
say lab': built from' n 'runs,' T~frames 'voiced frames; pitch window' T~window 'Hz'
say ''
say 'profile'~left(10) 'pitch window Hz'~left(18) 'overlap(st)'~right(11) 'timbre dist'~right(12) 'mean score'~right(11) 'threshold'~right(10) 'accepts'~right(8)
others=.array~new; do pf over profs~space~makeArray(' '); others~append(.VoiceProfile~load(pf)); end
others~append(T)
do p over others
  ov=overlapSt(T~winLo,T~winHi,p~winLo,p~winHi)
  d=0; do b=1 to T~nb; ps=RxCalcSqrt((T~sd[b]**2+p~sd[b]**2)/2,16); q=(T~mu[b]-p~mu[b])/ps; d+=q*q; end
  d=RxCalcSqrt(d/T~nb,16)
  s=0; acc=0; do r over runsT; sc=p~runScore(r); s+=sc; if sc>=p~threshold then acc+=1; end
  say p~label~left(10) (format(p~winLo,,1)'-'format(p~winHi,,1))~left(18) format(ov,,1)~right(11) format(d,,2)~right(12) format(s/runsT~items,,3)~right(11) format(p~threshold,,3)~right(10) (acc'/'runsT~items)~right(8)
end
exit 0
overlapSt: procedure
  use arg a0, a1, b0, b1
  lo=max(a0,b0); hi=min(a1,b1); if hi<=lo then return 0
  return 12*RxCalcLog(hi/lo,16)/RxCalcLog(2,16)
::requires 'VoiceProfile.cls'
::requires 'rxmath' LIBRARY
