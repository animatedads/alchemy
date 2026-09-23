/* AudioParetoObjectives.cls - quality-target calibrated recovered-audio Pareto objective adapter.
   Keeps resemblance and artefact evidence separate instead of hiding 18/40 penalty weights in one scalar. */

::class AudioParetoObjectives public
::method create class
  objectives=.array~new
  objectives~append(.MLObjective~new('reference_distance','MINIMIZE','0.35*global + 0.40*window_median + 0.10*window_p25 + 0.15*temporal','quality-target resemblance without clipping penalty scalarization'))
  objectives~append(.MLObjective~new('pre_limiter_over_fraction','MINIMIZE','pre_limiter_over_fraction','fraction exceeding pre-limiter reference range'))
  objectives~append(.MLObjective~new('post_limiter_clip_fraction','MINIMIZE','post_limiter_clip_fraction','fraction clipped after limiter'))
  return .MLObjectiveSet~new('RECOVERED-AUDIO-PARETO-V2',objectives,'audio quality-target/artefact tradeoffs retained explicitly')
::method scoresFromStats class
  use strict arg stats
  if \stats~isA(.Directory) then raise syntax 88.900 array('audio Pareto stats must be Directory')
  required=.array~of('global_distance','window_median_distance','window_p25_distance','temporal_distance','pre_limiter_over_fraction','post_limiter_clip_fraction')
  do key over required
    if \stats~hasIndex(key) then raise syntax 88.900 array('audio Pareto stats missing metric',key)
  end
  scores=.directory~new
  scores['reference_distance']=.35*stats['global_distance']+.40*stats['window_median_distance']+.10*stats['window_p25_distance']+.15*stats['temporal_distance']
  scores['pre_limiter_over_fraction']=stats['pre_limiter_over_fraction']
  scores['post_limiter_clip_fraction']=stats['post_limiter_clip_fraction']
  return scores
::method candidateFromRecord class
  use strict arg id,laneId,configuration,stats,materialRefs=.nil
  objectives=self~create; vector=objectives~vector(self~scoresFromStats(stats))
  return .MLParetoSearchCandidate~new(id,laneId,configuration,vector,stats,materialRefs)

::requires "OorexxML.cls"
