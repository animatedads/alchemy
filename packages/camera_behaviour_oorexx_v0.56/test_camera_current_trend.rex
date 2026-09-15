/* Rolling current-condition trend tests for CameraCore.cls */

say 'CAMERA CURRENT TREND SMOKE START'

camera = .CameraModel~new('CAMTREND', 640, 360)
conditionModel = .CameraCurrentConditionModel~new(300, 4, 1.0, 2.5, 4.0, 2, 2.0, 3)

/* A sustained rise can describe a changing scene before the mean level itself is elevated. */
risingValues = .array~of(0.0, 0.7, 1.4, 2.2)
do sampleIndex = 1 to risingValues~items
  assessment = .CameraClipAssessment~new('rise' || sampleIndex, 900 + (sampleIndex * 60), .CameraConstant~DAY_UNKNOWN)
  metric = .CameraMetricAssessment~new('TRACK_RATE', 0, 0, risingValues[sampleIndex], 6, .CameraConstant~BASELINE_WITHIN, 'ALL')
  assessment~addMetric(metric)
  observedCount = conditionModel~observeAssessment(assessment, 900 + (sampleIndex * 60))
end
risingCondition = conditionModel~currentCondition(camera, .CameraConstant~DAY_UNKNOWN, 1140, 3)
risingSignal = risingCondition~metricSignal('TRACK_RATE')
call assertEqual 'rising state', .CameraConstant~CONDITION_SHIFTED, risingCondition~state
call assertEqual 'one trending metric', 1, risingCondition~trendingMetricCount
call assertEqual 'rising trend state', .CameraConstant~TREND_RISING, risingSignal~trendState
call assertNear 'rising trend delta', 2.2, risingSignal~trendDelta, 0.0001
call assertTrue 'rising average remains below level threshold', abs(risingSignal~averageZ) < conditionModel~metricElevatedZ
call assertEqual 'rising strongest trend metric', 'TRACK_RATE', risingCondition~strongestTrendMetricName

/* Falling movement is equally explicit: trend direction is retained, not converted to magnitude only. */
conditionModel~clear
fallingValues = .array~of(1.8, 1.0, 0.2, -0.5)
do sampleIndex = 1 to fallingValues~items
  assessment = .CameraClipAssessment~new('fall' || sampleIndex, 1200 + (sampleIndex * 60), .CameraConstant~DAY_UNKNOWN)
  metric = .CameraMetricAssessment~new('INTERACTION_RATE', 0, 0, fallingValues[sampleIndex], 6, .CameraConstant~BASELINE_WITHIN, 'ALL')
  assessment~addMetric(metric)
  observedCount = conditionModel~observeAssessment(assessment, 1200 + (sampleIndex * 60))
end
fallingCondition = conditionModel~currentCondition(camera, .CameraConstant~DAY_UNKNOWN, 1440, 3)
fallingSignal = fallingCondition~metricSignal('INTERACTION_RATE')
call assertEqual 'falling state', .CameraConstant~CONDITION_SHIFTED, fallingCondition~state
call assertEqual 'falling trend state', .CameraConstant~TREND_FALLING, fallingSignal~trendState
call assertNear 'falling trend delta', -2.3, fallingSignal~trendDelta, 0.0001
call assertTrue 'signed strongest trend retained', fallingCondition~strongestTrendDelta < 0

/* Normal jitter is not promoted to a trend. */
conditionModel~clear
stableValues = .array~of(0.2, -0.1, 0.1, 0.3)
do sampleIndex = 1 to stableValues~items
  assessment = .CameraClipAssessment~new('stable' || sampleIndex, 1500 + (sampleIndex * 60), .CameraConstant~DAY_UNKNOWN)
  metric = .CameraMetricAssessment~new('TRACK_RATE', 0, 0, stableValues[sampleIndex], 6, .CameraConstant~BASELINE_WITHIN, 'ALL')
  assessment~addMetric(metric)
  observedCount = conditionModel~observeAssessment(assessment, 1500 + (sampleIndex * 60))
end
stableCondition = conditionModel~currentCondition(camera, .CameraConstant~DAY_UNKNOWN, 1740, 3)
stableSignal = stableCondition~metricSignal('TRACK_RATE')
call assertEqual 'stable state expected', .CameraConstant~CONDITION_EXPECTED, stableCondition~state
call assertEqual 'stable trend state', .CameraConstant~TREND_STABLE, stableSignal~trendState
call assertEqual 'no trending metrics', 0, stableCondition~trendingMetricCount

/* Fewer than the configured number of samples cannot create a trend. */
conditionModel~clear
do sampleIndex = 1 to 2
  assessment = .CameraClipAssessment~new('short' || sampleIndex, 1800 + (sampleIndex * 60), .CameraConstant~DAY_UNKNOWN)
  zValue = (sampleIndex - 1) * 5
  metric = .CameraMetricAssessment~new('TRACK_RATE', 0, 0, zValue, 6, .CameraConstant~BASELINE_WITHIN, 'ALL')
  assessment~addMetric(metric)
  observedCount = conditionModel~observeAssessment(assessment, 1800 + (sampleIndex * 60))
end
shortCondition = conditionModel~currentCondition(camera, .CameraConstant~DAY_UNKNOWN, 1920, 3)
shortSignal = shortCondition~metricSignal('TRACK_RATE')
call assertEqual 'short sequence trend stable', .CameraConstant~TREND_STABLE, shortSignal~trendState
call assertEqual 'short sequence no trend count', 0, shortCondition~trendingMetricCount

say '  rising delta: ' risingSignal~trendDelta
say '  falling delta:' fallingSignal~trendDelta
say 'CAMERA CURRENT TREND SMOKE: OK'
exit 0

assertEqual: procedure
  use arg label, expected, actual
  if expected == actual then return .true
  say 'ASSERT FAILED:' label
  say '  expected:' expected
  say '  actual:  ' actual
  exit 1

assertNear: procedure
  use arg label, expected, actual, tolerance
  if abs(expected - actual) <= tolerance then return .true
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
