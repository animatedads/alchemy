/* Alchemy v0.8 method execution provenance integration. */
say 'CAMERA EXECUTION PROVENANCE SMOKE START'

camera=.CameraModel~new('CAMPROV',640,360)

/* The three decision-pipeline methods are dynamically wrapped by Alchemy v0.8. */
do name over .array~of('ASSESSSUMMARYATGENERATION','OBSERVEASSESSMENTTREND','OBSERVEASSESSMENTTRENDSTATE')
  telemetry=camera~methodTelemetry
  call assertTrue name 'telemetry registry exists', telemetry \== .nil
end

/* Exercise trend calls with a compact synthetic assessment. */
a=.CameraClipAssessment~new('P1',43200,.CameraConstant~DAY_WEEKDAY,'G1')
m=.CameraMetricAssessment~new('TRACK_RATE',4,0,4,10,.CameraConstant~BASELINE_ELEVATED,'DAY:121')
ignored=a~addMetric(m)
a~evidence=.CameraProvEvidence~new(.CameraConstant~ENV_DAY_DIFFUSE)

beforeRegistry=camera~methodTelemetry
before=beforeRegistry['OBSERVEASSESSMENTTREND']
if before == .nil then beforeCalls=0
else beforeCalls=before['calls']
ignored=camera~observeAssessmentTrend(a)
afterRegistry=camera~methodTelemetry
after=afterRegistry['OBSERVEASSESSMENTTREND']

call assertTrue 'trend telemetry call count advances', after['calls'] > beforeCalls
call assertEqual 'trend telemetry failures', 0, after['failures']

construction=camera~alchemyConstructionProvenance
call assertEqual 'construction uses v0.8 INIT path','INIT',construction['entrypoint']
call assertEqual 'base version','0.8',camera~alchemyBaseState['base_version']

say '  OBSERVEASSESSMENTTREND calls:' after['calls']
say '  construction:' construction['entrypoint'] 'base=' camera~alchemyBaseState['base_version']
say 'CAMERA EXECUTION PROVENANCE SMOKE: OK'
exit 0

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

::class CameraProvEvidence public
::attribute environmentCode get
::method init
 expose environmentCode
 use arg environmentCode

::requires 'CameraCore.cls'
