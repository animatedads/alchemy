/* Face SLAM gait v0.1-dev2: projected 2-D limb trajectory review.
 * Upstream providers own pose inference; Motion Control owns track identity.
 * This module analyses measured joint trajectories only, without asserting
 * footsteps, walking speed, biometric identity or cross-person associations.
 * Source timestamps must be source-global integer microseconds.
 */
::class FaceSlamGaitTemporal public
::attribute maxGapUs get
::attribute minimumSamples get
::attribute minimumDurationUs get
::attribute phaseThreshold get
::attribute minimumKneeRange get
::method init
  expose maxGapUs minimumSamples minimumDurationUs phaseThreshold minimumKneeRange
  use strict arg maxGapUs=400000,minimumSamples=7,minimumDurationUs=500000,phaseThreshold='0.08',minimumKneeRange=12
  numeric digits 30
  if \maxGapUs~datatype('W') | maxGapUs<1 then raise syntax 88.900 array('maxGapUs must be positive integer')
  if \minimumSamples~datatype('W') | minimumSamples<3 then raise syntax 88.900 array('minimumSamples must be integer >= 3')
  if \minimumDurationUs~datatype('W') | minimumDurationUs<1 then raise syntax 88.900 array('minimumDurationUs must be positive integer')
  if \phaseThreshold~datatype('N') | phaseThreshold<=0 then raise syntax 88.900 array('phaseThreshold must be positive')
  if \minimumKneeRange~datatype('N') | minimumKneeRange<0 then raise syntax 88.900 array('minimumKneeRange must be nonnegative')
  maxGapUs=maxGapUs+0; minimumSamples=minimumSamples+0; minimumDurationUs=minimumDurationUs+0

::method result private
  use strict arg status,reason
  out=.directory~new
  out['status']=status
  out['reason']=reason
  out['interpretation']='2D projected limb variation only; not verified steps, cadence, gait identity or physical speed'
  return out

::method assess
  expose maxGapUs minimumSamples minimumDurationUs phaseThreshold minimumKneeRange
  use strict arg observations
  numeric digits 30
  if \observations~isA(.Array) then raise syntax 88.900 array('gait sequence must be Array')
  out=self~result('INSUFFICIENT','TOO_FEW_SAMPLES')
  out['sampleCount']=observations~items
  if observations~items<minimumSamples then return out
  first=observations[1]
  if first~class~id\='FACESLAMGAITFEATURE' then return self~result('BLOCKED','INVALID_FEATURE_TYPE')
  sourceId=first~sourceId; trackId=first~trackId
  initialTime=first~timeUs; previousTime=-1
  phase=0; reversals=0; lastReversalTime=-1
  firstReversalTime=-1; intervalSum=0; intervals=0
  leftLow=999; rightLow=999; leftHigh=-999; rightHigh=-999
  minConfidence=1
  do feature over observations
    if feature~class~id\='FACESLAMGAITFEATURE' then return self~result('BLOCKED','INVALID_FEATURE_TYPE')
    if feature~status\='OK' then return self~result('BLOCKED','NON_MEASUREMENT')
    if feature~sourceId\==sourceId | feature~trackId\==trackId then return self~result('BLOCKED','MIXED_TRACK_OR_SOURCE')
    t=feature~timeUs
    if previousTime>=0 then do
      if t<=previousTime then return self~result('BLOCKED','NON_MONOTONIC_SOURCE_PTS')
      if t-previousTime>maxGapUs then return self~result('SEGMENT_REQUIRED','SOURCE_PTS_GAP')
    end
    previousTime=t
    left=feature~leftKneeDegrees; right=feature~rightKneeDegrees
    offset=feature~signedAnkleOffsetTorso
    if \left~datatype('N') | \right~datatype('N') | \offset~datatype('N') then return self~result('BLOCKED','NON_NUMERIC_LIMB_MEASUREMENT')
    if left<0 | left>180 | right<0 | right>180 then return self~result('BLOCKED','OUT_OF_RANGE_KNEE_ANGLE')
    if left<leftLow then leftLow=left
    if right<rightLow then rightLow=right
    if left>leftHigh then leftHigh=left
    if right>rightHigh then rightHigh=right
    confidence=feature~confidenceFloor
    if \confidence~datatype('N') | confidence<0 | confidence>1 then return self~result('BLOCKED','INVALID_CONFIDENCE')
    if confidence<minConfidence then minConfidence=confidence
    nextPhase=0
    if offset>=phaseThreshold then nextPhase=1
    if offset<=-phaseThreshold then nextPhase=-1
    if nextPhase\=0 then do
      if phase\=0 & phase\=nextPhase then do
        reversals=reversals+1
        if firstReversalTime=-1 then firstReversalTime=t
        if lastReversalTime>=0 then do
          intervalSum=intervalSum+(t-lastReversalTime)
          intervals=intervals+1
        end
        lastReversalTime=t
      end
      phase=nextPhase
    end
  end
  duration=previousTime-initialTime
  out=self~result('DESCRIPTIVE_ONLY','NO_REPEATABLE_PERIODICITY_ESTABLISHED')
  out['sampleCount']=observations~items
  out['sourceId']=sourceId; out['trackId']=trackId
  out['startTimeUs']=initialTime; out['endTimeUs']=previousTime
  out['durationUs']=duration
  out['ankleOrderReversals']=reversals
  out['leftKneeExcursionDegrees']=leftHigh-leftLow
  out['rightKneeExcursionDegrees']=rightHigh-rightLow
  out['minimumLandmarkConfidence']=minConfidence
  if intervals>0 then out['meanReversalIntervalUs']=intervalSum/intervals
  else out['meanReversalIntervalUs']=.nil
  if duration<minimumDurationUs then do
    out['status']='INSUFFICIENT'; out['reason']='OBSERVATION_TOO_SHORT'; return out
  end
  if reversals<3 then return out
  if leftHigh-leftLow<minimumKneeRange | rightHigh-rightLow<minimumKneeRange then do
    out['reason']='INSUFFICIENT_KNEE_EXCURSION'; return out
  end
  out['status']='MOTION_PERIODICITY_CANDIDATE'
  out['reason']='ANKLE_ORDER_REVERSALS_AND_KNEE_EXCURSION'
  return out
