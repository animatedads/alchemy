/* AudioV9TransientReflectorTrajectory.cls
 * dev19: fail-closed moving-reflector geometry and acoustic admission.
 *
 * Geometry predicts a time-varying path delay.  It never creates acoustic
 * authority.  A virtual-microphone candidate is AVAILABLE only when repeated
 * audio-authoritative observations follow that prediction within policy.
 */
::options numeric inherit

::class AudioV9Point3D public
::method init
  expose x y z
  use strict arg xValue,yValue,zValue=0
  x=xValue+0; y=yValue+0; z=zValue+0
::method x; expose x; return x
::method y; expose y; return y
::method z; expose z; return z
::method distanceTo
  expose x y z
  use strict arg other
  if \other~isA(.AudioV9Point3D) then raise syntax 88.900 array('distance target must be AudioV9Point3D')
  d=(x-other~x)**2+(y-other~y)**2+(z-other~z)**2
  return self~sqrt(d)
::method sqrt private
  use strict arg value
  if value<0 then raise syntax 88.900 array('negative squared distance')
  if value=0 then return 0
  guess=value; if guess<1 then guess=1
  do 80
    next=(guess+value/guess)/2
    if abs(next-guess)<1E-20 then return next
    guess=next
  end
  return guess

::class AudioV9ReflectorTrajectorySample public
::method init
  expose timeMs position geometryScore occupancyId provenance
  use strict arg timeValue,positionValue,scoreValue,occupancyValue='',provenanceValue='VIDEO_GEOMETRY'
  timeMs=timeValue+0; position=positionValue; geometryScore=scoreValue+0
  occupancyId=occupancyValue~string; provenance=provenanceValue~string
  if \position~isA(.AudioV9Point3D) then raise syntax 88.900 array('trajectory sample requires AudioV9Point3D')
  if geometryScore<0 | geometryScore>1 then raise syntax 88.900 array('geometry score must be 0..1')
::method timeMs; expose timeMs; return timeMs
::method position; expose position; return position
::method geometryScore; expose geometryScore; return geometryScore
::method occupancyId; expose occupancyId; return occupancyId
::method provenance; expose provenance; return provenance

::class AudioV9PredictedReflection public
::method init
  expose timeMs directDistance reflectedDistance excessDistance excessDelaySamples geometryScore occupancyId
  use strict arg timeValue,directValue,reflectedValue,delayValue,scoreValue,occupancyValue=''
  timeMs=timeValue+0; directDistance=directValue+0; reflectedDistance=reflectedValue+0
  excessDistance=reflectedDistance-directDistance; excessDelaySamples=delayValue+0
  geometryScore=scoreValue+0; occupancyId=occupancyValue~string
  if directDistance<0 | reflectedDistance<directDistance | excessDelaySamples<0 then raise syntax 88.900 array('invalid predicted reflection')
::method timeMs; expose timeMs; return timeMs
::method directDistance; expose directDistance; return directDistance
::method reflectedDistance; expose reflectedDistance; return reflectedDistance
::method excessDistance; expose excessDistance; return excessDistance
::method excessDelaySamples; expose excessDelaySamples; return excessDelaySamples
::method geometryScore; expose geometryScore; return geometryScore
::method occupancyId; expose occupancyId; return occupancyId

::class AudioV9TransientReflectorGeometry public
::method init
  expose source receiver sampleRate soundSpeed
  use strict arg sourceValue,receiverValue,sampleRateValue,soundSpeedValue=343
  source=sourceValue; receiver=receiverValue; sampleRate=sampleRateValue+0; soundSpeed=soundSpeedValue+0
  if \source~isA(.AudioV9Point3D) | \receiver~isA(.AudioV9Point3D) then raise syntax 88.900 array('transient reflector geometry requires source and receiver points')
  if sampleRate<=0 | soundSpeed<=0 then raise syntax 88.900 array('invalid sample rate or sound speed')
::method predict
  expose source receiver sampleRate soundSpeed
  use strict arg trajectorySample
  if \trajectorySample~isA(.AudioV9ReflectorTrajectorySample) then raise syntax 88.900 array('predict requires trajectory sample')
  direct=source~distanceTo(receiver)
  reflected=source~distanceTo(trajectorySample~position)+trajectorySample~position~distanceTo(receiver)
  if reflected<direct then reflected=direct
  delay=(reflected-direct)*sampleRate/soundSpeed
  return .AudioV9PredictedReflection~new(trajectorySample~timeMs,direct,reflected,delay,trajectorySample~geometryScore,trajectorySample~occupancyId)

::class AudioV9TransientPathMatch public
::method init
  expose observationId prediction observedDelay residualSamples acousticScore selfNoiseScore directDropDb hypothesis admitted reason
  use strict arg idValue,predictionValue,observedValue,acousticValue,selfNoiseValue,directDropValue,hypothesisValue,admittedValue,reasonValue
  observationId=idValue~string; prediction=predictionValue; observedDelay=observedValue+0
  residualSamples=abs(observedDelay-prediction~excessDelaySamples); acousticScore=acousticValue+0
  selfNoiseScore=selfNoiseValue+0; directDropDb=directDropValue+0; hypothesis=hypothesisValue~string
  admitted=(admittedValue<>0); reason=reasonValue~string
::method observationId; expose observationId; return observationId
::method prediction; expose prediction; return prediction
::method observedDelay; expose observedDelay; return observedDelay
::method residualSamples; expose residualSamples; return residualSamples
::method acousticScore; expose acousticScore; return acousticScore
::method selfNoiseScore; expose selfNoiseScore; return selfNoiseScore
::method directDropDb; expose directDropDb; return directDropDb
::method hypothesis; expose hypothesis; return hypothesis
::method admitted; expose admitted; return admitted
::method reason; expose reason; return reason

::class AudioV9TransientReflectorPolicy public
::method init
  expose audioGate geometryGate maxResidualSamples selfNoiseGate blockageDropDb minimumMatches
  use strict arg audioGateValue=.55,geometryGateValue=.50,maxResidualValue=3,selfNoiseGateValue=.70,blockageDropValue=6,minimumMatchesValue=3
  audioGate=audioGateValue+0; geometryGate=geometryGateValue+0; maxResidualSamples=maxResidualValue+0
  selfNoiseGate=selfNoiseGateValue+0; blockageDropDb=blockageDropValue+0; minimumMatches=minimumMatchesValue+0
  if audioGate<0 | audioGate>1 | geometryGate<0 | geometryGate>1 | maxResidualSamples<0 then raise syntax 88.900 array('invalid transient reflector policy')
  if selfNoiseGate<0 | selfNoiseGate>1 | blockageDropDb<0 | minimumMatches<2 then raise syntax 88.900 array('invalid transient reflector policy')
::method classify
  expose audioGate geometryGate maxResidualSamples selfNoiseGate blockageDropDb
  use strict arg observationId,prediction,observedDelay,acousticScore,selfNoiseScore=0,directDropDb=0
  if \prediction~isA(.AudioV9PredictedReflection) then raise syntax 88.900 array('classification requires predicted reflection')
  a=acousticScore+0; n=selfNoiseScore+0; drop=directDropDb+0
  if a<0 | a>1 | n<0 | n>1 then raise syntax 88.900 array('scores must be 0..1')
  residual=abs((observedDelay+0)-prediction~excessDelaySamples)
  if n>=selfNoiseGate & a<audioGate then return .AudioV9TransientPathMatch~new(observationId,prediction,observedDelay,a,n,drop,'H3_SELF_NOISE',0,'vehicle energy without admitted speech-coherent path')
  if drop>=blockageDropDb & a<audioGate then return .AudioV9TransientPathMatch~new(observationId,prediction,observedDelay,a,n,drop,'H2_BLOCKAGE',0,'direct path fell without admitted reflected path')
  if prediction~geometryScore<geometryGate then return .AudioV9TransientPathMatch~new(observationId,prediction,observedDelay,a,n,drop,'H0_NO_CHANGE',0,'geometry prediction below policy gate')
  if a<audioGate then return .AudioV9TransientPathMatch~new(observationId,prediction,observedDelay,a,n,drop,'H0_NO_CHANGE',0,'acoustic path below authority gate')
  if residual>maxResidualSamples then return .AudioV9TransientPathMatch~new(observationId,prediction,observedDelay,a,n,drop,'H0_NO_CHANGE',0,'audio delay does not follow geometry')
  return .AudioV9TransientPathMatch~new(observationId,prediction,observedDelay,a,n,drop,'H1_REFLECTION',1,'audio-authoritative delay follows moving-reflector prediction')
::method virtualMicrophoneCandidate
  expose minimumMatches maxResidualSamples
  use strict arg matches
  if \matches~isA(.Array) then raise syntax 88.900 array('virtual microphone admission requires Array')
  admitted=0; residual=0; previousTime=.nil
  do m over matches
    if \m~isA(.AudioV9TransientPathMatch) then raise syntax 88.900 array('invalid transient path match')
    if \m~admitted then do
      if previousTime\==.nil then if m~prediction~timeMs<=previousTime then return .AudioV9VirtualMicrophoneCandidate~new('UNAVAILABLE',admitted,'NON_MONOTONIC_TRAJECTORY',0)
      previousTime=m~prediction~timeMs; admitted=admitted+1; residual=residual+m~residualSamples
    end
  end
  if admitted<minimumMatches then return .AudioV9VirtualMicrophoneCandidate~new('UNAVAILABLE',admitted,'INSUFFICIENT_AUDIO_SUPPORTED_MATCHES',0)
  meanResidual=residual/admitted
  confidence=1-meanResidual/(maxResidualSamples+1)
  if confidence<0 then confidence=0
  return .AudioV9VirtualMicrophoneCandidate~new('AVAILABLE',admitted,'AUDIO_SUPPORTED_TRANSIENT_PATH',confidence)

::class AudioV9VirtualMicrophoneCandidate public
::method init
  expose state matchCount reason confidence
  use strict arg stateValue,countValue,reasonValue,confidenceValue
  state=stateValue~string~upper; matchCount=countValue+0; reason=reasonValue~string; confidence=confidenceValue+0
  if state\='AVAILABLE' & state\='UNAVAILABLE' then raise syntax 88.900 array('invalid virtual microphone state')
::method state; expose state; return state
::method matchCount; expose matchCount; return matchCount
::method reason; expose reason; return reason
::method confidence; expose confidence; return confidence
::method available; expose state; return state='AVAILABLE'
