objectives=.AudioParetoObjectives~create
st=.directory~new
st['global_distance']=1.0; st['window_median_distance']=2.0; st['window_p25_distance']=3.0; st['temporal_distance']=4.0
st['pre_limiter_over_fraction']=.01; st['post_limiter_clip_fraction']=.002
scores=.AudioParetoObjectives~scoresFromStats(st)
call true scores['reference_distance']>2.04 & scores['reference_distance']<2.06,'reference objective uses distance blend only'
call eq scores['pre_limiter_over_fraction'],.01,'pre-limiter evidence remains independent objective'
call eq scores['post_limiter_clip_fraction'],.002,'post-limiter clipping remains independent objective'
call eq objectives~items,3,'audio Pareto adapter declares three separate objectives'
say 'PASS test_audio_pareto_objectives'
exit 0

eq: procedure
 use arg a,e,l
 if a\==e then do; say 'FAIL' l; say ' expected='e; say ' actual  ='a; exit 1; end
 return
true: procedure
 use arg v,l
 if \v then do; say 'FAIL' l; exit 1; end
 return
::requires "AudioParetoObjectives.cls"
