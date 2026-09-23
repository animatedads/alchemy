/* AudioV9SpatialEvidence.cls
 * Spatial hypotheses + ML contextual fit.  Wobble is diagnostic only.
 */

::options numeric inherit

::class AudioV9ConstantDelayFitScorer public
::method assess
  use strict arg observations
  n=observations~items
  if n<2 then raise syntax 88.900 array('constant delay fit requires at least two observations')
  sum=0
  do o over observations
    if \o~isA(.Directory) | \o~hasIndex('lag_ms') then raise syntax 88.900 array('delay observation requires lag_ms')
    sum=sum+(o['lag_ms']+0)
  end
  mean=sum/n; ss=0; maxAbs=0
  do o over observations
    e=(o['lag_ms']+0)-mean; ss=ss+e*e; if abs(e)>maxAbs then maxAbs=abs(e)
  end
  rms=self~sqrt(ss/n)
  ev=.directory~new; ev['mean_lag_ms']=mean; ev['rms_ms']=rms; ev['max_abs_ms']=maxAbs
  return .MLFitAssessment~new(rms,n,'AUDIO_CONSTANT_DELAY',ev)
::method sqrt private
  use strict arg x
  numeric digits 30
  if x<0 then raise syntax 88.900 array('sqrt requires non-negative x',x)
  if x=0 then return 0
  if x<1 then g=1; else g=x
  do i=1 to 48; g=(g+x/g)/2; end
  return g

::class AudioV9DelayTrackAnalyzer public
::method init
  expose threshold maxRemovals maxEvaluations
  use strict arg rmsThresholdMs=3.0,maxRemovalsValue=4,maxEvaluationsValue=100000
  threshold=rmsThresholdMs+0; maxRemovals=maxRemovalsValue+0; maxEvaluations=maxEvaluationsValue+0
  if threshold<0 then raise syntax 88.900 array('delay fit threshold must be non-negative')
::method analyze
  expose threshold maxRemovals maxEvaluations
  use strict arg observations
  if \observations~isA(.Array) | observations~items<3 then raise syntax 88.900 array('delay wobble analysis requires at least three observations')
  /* Constant-delay fitting itself needs at least two retained observations.
   * Bound diagnostic exclusion accordingly rather than letting a generic
   * wobble search create an invalid one-observation fit problem. */
  effective=maxRemovals
  if effective>observations~items-2 then effective=observations~items-2
  scorer=.AudioV9ConstantDelayFitScorer~new
  criterion=.MLFitCriterion~new(threshold,'LOWER_IS_BETTER')
  search=.MLWobbleSetSearch~new(scorer,criterion,effective,maxEvaluations)
  return search~analyze(observations)

::class AudioV9SpatialHypothesis public
::method init
  expose id lagMs source score evidence
  use strict arg idValue,lagMsValue,sourceValue,scoreValue,evidenceValue=.nil
  id=idValue~string; lagMs=lagMsValue+0; source=sourceValue~string; score=scoreValue+0
  if evidenceValue==.nil then evidence=.directory~new; else evidence=evidenceValue
::method id; expose id; return id
::method lagMs; expose lagMs; return lagMs
::method source; expose source; return source
::method score; expose score; return score
::method evidence; expose evidence; return evidence
::method canonicalText
  expose id lagMs source score
  return 'AUDIO_V9_SPATIAL_HYPOTHESIS/1|id='||id||'|lagMs='||lagMs||'|source='||source||'|score='||score

::class AudioV9SpatialHypothesisBuilder public
::method fromMeasurement
  use strict arg measurement
  if \measurement~isA(.AudioV9SpatialMeasurement) then raise syntax 88.900 array('spatial hypothesis builder requires AudioV9SpatialMeasurement')
  out=.array~new
  e=.directory~new; e['coherence']=measurement~directCoherence; e['ratio_db']=measurement~ratioDb
  out~append(.AudioV9SpatialHypothesis~new('ENVELOPE',measurement~envelopeLagMs,'ENVELOPE',measurement~envelopeScore,e))
  f=.directory~new; f['coherence']=measurement~directCoherence; f['ratio_db']=measurement~ratioDb
  out~append(.AudioV9SpatialHypothesis~new('DIRECT',measurement~directLagMs,'WAVEFORM_ZERO_CENTRED',measurement~directScore,f))
  r=.directory~new; r['coherence']=measurement~refinedCoherence; r['ratio_db']=measurement~ratioDb
  out~append(.AudioV9SpatialHypothesis~new('REFINED',measurement~refinedLagMs,'ENVELOPE_REFINED_WAVEFORM',measurement~refinedScore,r))
  return out

::class AudioV9VoiceEvidence public
::method init
  expose values
  use strict arg source=.nil
  values=.directory~new
  if source\==.nil then do
    if \source~isA(.Directory) then raise syntax 88.900 array('voice evidence source must be Directory')
    do k over source~allIndexes; values[k]=source[k]; end
  end
::method put
  expose values
  use strict arg key,value
  values[key~string]=value; return self
::method at
  expose values
  use strict arg key,default=.nil
  k=key~string
  if \values~hasIndex(k) then return default
  return values[k]
::method numeric
  expose values
  use strict arg key,default=0
  k=key~string; if \values~hasIndex(k) then return default+0
  return values[k]+0
::method map; expose values; return values~copy

/* Conservative preservation policy. This is not a learned classifier.
 * It only establishes when later classifiers are allowed to hard-suppress.
 */
::class AudioV9SpeechPreservationPolicy public
::method init
  expose hardNegativeThreshold humanProtectionThreshold
  use strict arg hardNegativeThresholdValue=0.97,humanProtectionThresholdValue=0.20
  hardNegativeThreshold=hardNegativeThresholdValue+0; humanProtectionThreshold=humanProtectionThresholdValue+0
::method disposition
  expose hardNegativeThreshold humanProtectionThreshold
  use strict arg evidence
  if \evidence~isA(.AudioV9VoiceEvidence) then raise syntax 88.900 array('speech preservation requires AudioV9VoiceEvidence')
  human=evidence~numeric('human_voice',0)
  playback=evidence~numeric('camera_playback',0)
  alarm=evidence~numeric('alarm',0)
  animal=evidence~numeric('animal',0)
  background=evidence~numeric('background',0)
  impulse=evidence~numeric('impulse',0)
  negative=playback; label='CAMERA_PLAYBACK'
  if alarm>negative then do; negative=alarm; label='ALARM'; end
  if animal>negative then do; negative=animal; label='ANIMAL'; end
  if background>negative then do; negative=background; label='BACKGROUND'; end
  if negative>=hardNegativeThreshold & human<humanProtectionThreshold then return 'SUPPRESS|'||label
  if impulse>=hardNegativeThreshold then return 'PRESERVE_IMPAIRED|IMPULSE'
  if human>=humanProtectionThreshold then return 'PRESERVE|HUMAN_VOICE'
  return 'PRESERVE_UNCERTAIN|UNCERTAIN'

::class AudioV9FusionDecision public
::method init
  expose mode weightA weightB lagSamples reason
  use strict arg modeValue,weightAValue,weightBValue,lagSamplesValue,reasonValue
  mode=modeValue~string; weightA=weightAValue+0; weightB=weightBValue+0; lagSamples=lagSamplesValue+0; reason=reasonValue~string
::method mode; expose mode; return mode
::method weightA; expose weightA; return weightA
::method weightB; expose weightB; return weightB
::method lagSamples; expose lagSamples; return lagSamples
::method reason; expose reason; return reason
::method canonicalText
  expose mode weightA weightB lagSamples reason
  return 'AUDIO_V9_FUSION_DECISION/1|mode='||mode||'|weightA='||weightA||'|weightB='||weightB||'|lagSamples='||lagSamples||'|reason='||reason

/* Deterministic candidate selector. Learned speech/non-speech scores are inputs;
 * this class never fabricates them and never makes suppression decisions.
 */
::class AudioV9FusionSelector public
::method choose
  use strict arg measurement,scoreA,scoreB,scoreCoherent,delayedScore=0,delayedLagSamples=0
  a=scoreA+0; b=scoreB+0; c=scoreCoherent+0; d=delayedScore+0
  best=a; mode='FC'; wa=1; wb=0; lag=0; reason='FC_EVIDENCE'
  if b>best then do; best=b; mode='FD'; wa=0; wb=1; lag=0; reason='FD_EVIDENCE'; end
  if c>best then do; best=c; mode='COHERENT'; wa=.5; wb=.5; lag=measurement~refinedLagSamples; reason='DUAL_FEED_COHERENT_EVIDENCE'; end
  if d>best then do; best=d; mode='DELAYED_PATH'; wa=.5; wb=.5; lag=delayedLagSamples+0; reason='DELAYED_PATH_EVIDENCE'; end
  return .AudioV9FusionDecision~new(mode,wa,wb,lag,reason)

::requires "AudioV9SpatialNativeProvider.cls"
::requires "MLWobblyFit.cls"
