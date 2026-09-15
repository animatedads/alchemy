objectives=.AudioParetoObjectives~create
candidates=.array~new
candidates~append(makeCandidate('cleaner',objectives,1.10,.95,.90,1.00,.010,.0001))
candidates~append(makeCandidate('natural',objectives,1.00,.90,.85,.95,.020,.0000))
candidates~append(makeCandidate('aggressive',objectives,.75,.70,.72,.80,.080,.0060))
candidates~append(makeCandidate('balanced',objectives,.88,.82,.78,.86,.025,.0005))
candidates~append(makeCandidate('worse-all-round',objectives,1.30,1.20,1.10,1.25,.100,.0100))
analysis=.MLParetoSearchAnalysis~analyze(objectives,candidates)
say objectives~canonicalText
say 'PARETO_FRONTS='analysis~frontCount
say 'NON_DOMINATED='analysis~front(1)~items
do p over analysis~front(1)~points
  say p~canonicalText
end
retained=.MLParetoRetentionSelector~select(analysis,.MLRetentionPolicy~new(3,'CANDIDATE','PROMOTED_ONLY'))
say 'RETAINED='retained~items
exit 0

makeCandidate: procedure
  use strict arg id,objectives,global,median,p25,temporal,preover,postclip
  cfg=.directory~new; cfg['label']=id
  st=.directory~new; st['global_distance']=global; st['window_median_distance']=median; st['window_p25_distance']=p25; st['temporal_distance']=temporal; st['pre_limiter_over_fraction']=preover; st['post_limiter_clip_fraction']=postclip
  return .MLParetoSearchCandidate~new(id,'AUDIO-C-PARETO',cfg,objectives~vector(.AudioParetoObjectives~scoresFromStats(st)),st)
::requires "AudioParetoObjectives.cls"
