/* Producer identity partitions compact trend/persistent regime history. */
say 'CAMERA PRODUCER PARTITIONED TREND SMOKE START'

producerA='aaaaaaaaaaaaaaaaaaaaaaaa'
producerB='bbbbbbbbbbbbbbbbbbbbbbbb'
trend=.CameraSignatureTrendModel~new(.array~of(300,900,3600),3,16)
persist=.CameraSignatureTrendPersistenceModel~new(2,2,2)

/* Establish a persistent rising trend under producer A. */
do n=0 to 4
  z=0
  if n=2 then z=3
  if n=3 then z=4
  if n=4 then z=5
  sig=makeSignature('A'||n,43200+(n*60),'G1',producerA,z)
  snap=trend~observe(sig)
  cond=persist~observe(snap)
end
call assertEqual 'producer A reaches persistent',.CameraConstant~SIGNATURE_TREND_PHASE_PERSISTENT,cond~phase
call assertTrue 'producer A regime open',persist~activeRegime \== .nil
call assertEqual 'regime producer A',producerA,persist~activeRegime~productionToken
oldRegime=persist~activeRegime

/* Same G/day/environment but a new producer must reset trend population. */
sigB=makeSignature('B0',43500,'G1',producerB,5)
snapB=trend~observe(sigB)
condB=persist~observe(snapB)

call assertEqual 'new producer isolated trend sample',1,snapB~window(3600)~sampleCount
call assertEqual 'new producer retained in trend',producerB,snapB~productionToken
call assertEqual 'new producer starts stable',.CameraConstant~SIGNATURE_TREND_PHASE_STABLE,condB~phase
call assertEqual 'condition producer B',producerB,condB~productionToken
call assertTrue 'old regime closed on producer change',persist~activeRegime == .nil
call assertEqual 'old regime closed state',.CameraConstant~SIGNATURE_TREND_REGIME_CLOSED,oldRegime~state
call assertEqual 'old regime producer preserved',producerA,oldRegime~productionToken

/* Compact adjacent-signature comparison explicitly identifies producer change. */
before=makeSignature('X1',50000,'G9',producerA,1)
after=makeSignature('X2',50060,'G9',producerB,1)
delta=before~compareTo(after)
call assertEqual 'generation unchanged',0,delta~generationChanged
call assertEqual 'producer changed',1,delta~producerChanged
call assertEqual 'day unchanged',0,delta~dayClassChanged
call assertEqual 'environment unchanged',0,delta~environmentChanged
call assertTrue 'CAD carries producer flag',delta~compactText~pos('|P=1|')>0

call assertTrue 'CST carries producer',snapB~compactText~pos('|P='||producerB||'|')>0
call assertTrue 'CTC carries producer',condB~compactText~pos('|I='||producerB||'|')>0

say '  producer reset condition:' condB~compactText
say '  producer delta:' delta~compactText
say 'CAMERA PRODUCER PARTITIONED TREND SMOKE: OK'
exit 0

makeSignature: procedure
  use arg clipId,secondOfDay,generationId,producerToken,z
  a=.CameraClipAssessment~new(clipId,secondOfDay,.CameraConstant~DAY_WEEKDAY,generationId)
  if abs(z)>=2.5 then state=.CameraConstant~BASELINE_ELEVATED
  else state=.CameraConstant~BASELINE_WITHIN
  m=.CameraMetricAssessment~new('TRACK_RATE',z,0,z,10,state,'DAY:'||.CameraConstant~DAY_WEEKDAY)
  ignored=a~addMetric(m)
  a~evidence=.CameraV43Environment~new(.CameraConstant~ENV_DAY_DIFFUSE)
  a~productionIdentity=.CameraV43Producer~new(producerToken)
  return a~conditionSignature

assertEqual: procedure
 use arg label,expected,actual
 if expected==actual then return .true
 say 'ASSERT FAILED:' label
 say ' expected:' expected
 say ' actual:  ' actual
 exit 1

assertTrue: procedure
 use arg label,actual
 if actual then return .true
 say 'ASSERT FAILED:' label
 exit 1

::class CameraV43Environment public
::attribute environmentCode get
::method init
 expose environmentCode
 use arg environmentCode

::class CameraV43Producer public
::attribute compactToken get
::method init
 expose compactToken
 use arg compactToken

::requires 'CameraCore.cls'
