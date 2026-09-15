/* Rolling multivariate current-condition tests for CameraCore.cls */

say 'CAMERA CURRENT METRICS SMOKE START'

camera = .CameraModel~new('CAMMETRIC', 640, 360)
camera~behaviour~addWindow(.CameraBehaviourWindow~new(15 * 60, 45 * 60))

/* Establish narrow, inspectable 00:15 baselines for two independent behaviours. */
do sampleIndex = 1 to 6
  trackRate = 9 + (sampleIndex // 3)
  eventRate = 19 + (sampleIndex // 3)
  observed = camera~behaviour~observeMetric(15 * 60, 'TRACK_RATE', trackRate)
  observed = camera~behaviour~observeMetric(15 * 60, 'EVENT_RATE', eventRate)
end

conditionModel = .CameraCurrentConditionModel~new(300, 4, 1.0, 2.5, 4.0, 2)

/* No transition grammar is required for a clear multivariate traffic shift. */
shiftSummary = .CameraClipSummary~new('shift', 15 * 60, 60, .CameraConstant~ENV_NIGHT_ARTIFICIAL, .CameraConstant~DAY_UNKNOWN)
shiftSummary~trackCount = 16
shiftSummary~eventCount = 30
shiftAssessment = .CameraClipComparator~assess(camera, shiftSummary, 3, 2.5)
conditionModel~observeAssessment(shiftAssessment, shiftSummary~midpointSecond)
shiftCondition = conditionModel~currentCondition(camera, .CameraConstant~DAY_UNKNOWN, shiftSummary~midpointSecond, 3)
call assertEqual 'metric-only shift state', .CameraConstant~CONDITION_SHIFTED, shiftCondition~state
call assertTrue 'multiple usable metrics', shiftCondition~usableMetricCount >= 2
call assertTrue 'multiple elevated metrics', shiftCondition~elevatedMetricCount >= 2
call assertTrue 'strongest metric recorded', shiftCondition~strongestMetricName \= ''
call assertTrue 'track signal available', shiftCondition~metricSignal('TRACK_RATE') \== .nil
call assertTrue 'event signal available', shiftCondition~metricSignal('EVENT_RATE') \== .nil

/* A normal clip against the same baseline should remain expected. */
conditionModel~clear
normalSummary = .CameraClipSummary~new('normal', 15 * 60, 60, .CameraConstant~ENV_NIGHT_ARTIFICIAL, .CameraConstant~DAY_UNKNOWN)
normalSummary~trackCount = 10
normalSummary~eventCount = 20
normalAssessment = .CameraClipComparator~assess(camera, normalSummary, 3, 2.5)
conditionModel~observeAssessment(normalAssessment, normalSummary~midpointSecond)
normalCondition = conditionModel~currentCondition(camera, .CameraConstant~DAY_UNKNOWN, normalSummary~midpointSecond, 3)
call assertEqual 'normal metric condition', .CameraConstant~CONDITION_EXPECTED, normalCondition~state
call assertEqual 'normal elevated count', 0, normalCondition~elevatedMetricCount

/* One very strong dimension is enough to describe a real current-condition shift. */
conditionModel~clear
singleSummary = .CameraClipSummary~new('single', 15 * 60, 60, .CameraConstant~ENV_NIGHT_ARTIFICIAL, .CameraConstant~DAY_UNKNOWN)
singleSummary~trackCount = 20
singleSummary~eventCount = 20
singleAssessment = .CameraClipComparator~assess(camera, singleSummary, 3, 2.5)
conditionModel~observeAssessment(singleAssessment, singleSummary~midpointSecond)
singleCondition = conditionModel~currentCondition(camera, .CameraConstant~DAY_UNKNOWN, singleSummary~midpointSecond, 3)
call assertEqual 'single strong outlier shift', .CameraConstant~CONDITION_SHIFTED, singleCondition~state
call assertEqual 'single elevated metric count', 1, singleCondition~elevatedMetricCount
call assertEqual 'single strongest metric', 'TRACK_RATE', singleCondition~strongestMetricName

/* Rolling expiry removes stale metric assessments, including across midnight semantics. */
conditionModel~clear
oldAssessment = .CameraClipAssessment~new('old', 100, .CameraConstant~DAY_UNKNOWN)
oldMetric = .CameraMetricAssessment~new('TRACK_RATE', 20, 10, 10, 6, .CameraConstant~BASELINE_ELEVATED, 'ALL')
oldAssessment~addMetric(oldMetric)
conditionModel~observeAssessment(oldAssessment, 100)
emptyCondition = conditionModel~currentCondition(camera, .CameraConstant~DAY_UNKNOWN, 500, 3)
call assertEqual 'expired metric removed', 0, emptyCondition~metricAssessmentCount
call assertEqual 'expired-only condition insufficient', .CameraConstant~CONDITION_INSUFFICIENT, emptyCondition~state

say '  shifted strongest: ' shiftCondition~strongestMetricName shiftCondition~strongestMetricZ
say '  shifted elevated:  ' shiftCondition~elevatedMetricCount
say 'CAMERA CURRENT METRICS SMOKE: OK'
exit 0

assertEqual: procedure
  use arg label, expected, actual
  if expected == actual then return .true
  say 'ASSERT FAILED:' label
  say '  expected:' expected
  say '  actual:  ' actual
  exit 1

assertTrue: procedure
  use arg label, actual
  if actual then return .true
  say 'ASSERT FAILED:' label
  say '  actual:' actual
  exit 1

::requires 'CameraCore.cls'
