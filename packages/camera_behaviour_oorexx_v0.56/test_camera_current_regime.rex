/* Persistent current-condition regime event tests for CameraCore.cls */

say 'CAMERA CURRENT REGIME SMOKE START'

camera = .CameraModel~new('CAMREGIME', 640, 360)
conditionModel = .CameraCurrentConditionModel~new(1, 4, 1.0, 2.5, 4.0, 2, 2.0, 3, 3, 2)

/* A short spike never becomes a durable regime record. */
spike = .CameraClipAssessment~new('spike', 50, .CameraConstant~DAY_UNKNOWN)
spike~addMetric(.CameraMetricAssessment~new('TRACK_RATE', 0, 0, 5.0, 6, .CameraConstant~BASELINE_ELEVATED, 'ALL'))
observed = conditionModel~observeAssessment(spike, 50)
spikeCondition = conditionModel~currentCondition(camera, .CameraConstant~DAY_UNKNOWN, 50, 3)
call assertEqual 'spike has no regime', '', spikeCondition~activeRegimeId
call assertTrue 'spike active regime nil', conditionModel~activeRegime == .nil

clear = .CameraClipAssessment~new('clear', 52, .CameraConstant~DAY_UNKNOWN)
clear~addMetric(.CameraMetricAssessment~new('TRACK_RATE', 0, 0, 0.0, 6, .CameraConstant~BASELINE_WITHIN, 'ALL'))
observed = conditionModel~observeAssessment(clear, 52)
clearCondition = conditionModel~currentCondition(camera, .CameraConstant~DAY_UNKNOWN, 52, 3)
call assertEqual 'spike produced no completed regime', 0, conditionModel~completedRegimes~items

/* Three consecutive shifted assessments open one compact regime from first emergence. */
conditionModel~clear
call addMetricAssessment conditionModel, 's1', 100, 'TRACK_RATE', 5.0, .CameraConstant~BASELINE_ELEVATED
c1 = conditionModel~currentCondition(camera, .CameraConstant~DAY_UNKNOWN, 100, 3)
call assertEqual 'first emerging no regime', '', c1~activeRegimeId

call addMetricAssessment conditionModel, 's2', 102, 'TRACK_RATE', 5.2, .CameraConstant~BASELINE_ELEVATED
c2 = conditionModel~currentCondition(camera, .CameraConstant~DAY_UNKNOWN, 102, 3)
call assertEqual 'second emerging no regime', '', c2~activeRegimeId

call addMetricAssessment conditionModel, 's3', 104, 'TRACK_RATE', 6.1, .CameraConstant~BASELINE_ELEVATED
c3 = conditionModel~currentCondition(camera, .CameraConstant~DAY_UNKNOWN, 104, 3)
regime = conditionModel~activeRegime
call assertTrue 'persistent regime exists', regime \== .nil
call assertEqual 'regime starts at first emerging instant', 100, regime~startSecond
call assertEqual 'condition carries regime id', regime~id, c3~activeRegimeId
call assertEqual 'regime open', .CameraConstant~CONDITION_REGIME_OPEN, regime~state
call assertEqual 'regime strongest metric', 'TRACK_RATE', regime~peakMetricName
call assertTrue 'regime peak z retained', regime~peakMetricZ >= 5.0

/* Continued shift updates the same regime rather than opening another. */
call addMetricAssessment conditionModel, 's4', 106, 'EVENT_RATE', 7.2, .CameraConstant~BASELINE_ELEVATED
c4 = conditionModel~currentCondition(camera, .CameraConstant~DAY_UNKNOWN, 106, 3)
call assertEqual 'same regime id persists', regime~id, c4~activeRegimeId
call assertEqual 'event becomes peak metric', 'EVENT_RATE', regime~peakMetricName

/* First expected sample is recovery and keeps the regime open. */
call addMetricAssessment conditionModel, 'r1', 108, 'TRACK_RATE', 0.1, .CameraConstant~BASELINE_WITHIN
r1 = conditionModel~currentCondition(camera, .CameraConstant~DAY_UNKNOWN, 108, 3)
call assertEqual 'recovering phase', .CameraConstant~CONDITION_PHASE_RECOVERING, r1~persistencePhase
call assertEqual 'regime remains open through recovery', regime~id, r1~activeRegimeId

/* Second expected sample closes and archives the regime. */
call addMetricAssessment conditionModel, 'r2', 110, 'TRACK_RATE', -0.1, .CameraConstant~BASELINE_WITHIN
r2 = conditionModel~currentCondition(camera, .CameraConstant~DAY_UNKNOWN, 110, 3)
call assertEqual 'stable after recovery', .CameraConstant~CONDITION_PHASE_STABLE, r2~persistencePhase
call assertTrue 'no active regime after close', conditionModel~activeRegime == .nil
call assertEqual 'one completed regime', 1, conditionModel~completedRegimes~items
closed = conditionModel~completedRegimes[1]
call assertEqual 'closed regime state', .CameraConstant~CONDITION_REGIME_CLOSED, closed~state
call assertEqual 'closed regime end', 110, closed~endSecond
call assertEqual 'closed duration includes emergence', 10, closed~durationSeconds
call assertEqual 'closed peak metric retained', 'EVENT_RATE', closed~peakMetricName
call assertTrue 'closed regime has observations', closed~sampleCount >= 3

say '  regime:' closed~compactText
say 'CAMERA CURRENT REGIME SMOKE: OK'
exit 0

addMetricAssessment: procedure
  use arg model, assessmentId, timestamp, metricName, zScore, baselineState
  assessment = .CameraClipAssessment~new(assessmentId, timestamp, .CameraConstant~DAY_UNKNOWN)
  assessment~addMetric(.CameraMetricAssessment~new(metricName, 0, 0, zScore, 6, baselineState, 'ALL'))
  ignoredCount = model~observeAssessment(assessment, timestamp)
  return

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
  say '  expected: true'
  say '  actual:  ' actual
  exit 1

::requires 'CameraCore.cls'
