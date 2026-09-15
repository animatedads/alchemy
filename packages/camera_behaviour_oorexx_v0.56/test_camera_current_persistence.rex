/* Rolling current-condition persistence/recovery tests for CameraCore.cls */

say 'CAMERA CURRENT PERSISTENCE SMOKE START'

camera = .CameraModel~new('CAMPERSIST', 640, 360)
conditionModel = .CameraCurrentConditionModel~new(1, 4, 1.0, 2.5, 4.0, 2, 2.0, 3, 3, 2)

/* One shifted observation is emerging, not a persistent regime. */
assessment1 = .CameraClipAssessment~new('shift1', 100, .CameraConstant~DAY_UNKNOWN)
metric1 = .CameraMetricAssessment~new('TRACK_RATE', 0, 0, 5.0, 6, .CameraConstant~BASELINE_ELEVATED, 'ALL')
assessment1~addMetric(metric1)
observedCount = conditionModel~observeAssessment(assessment1, 100)
condition1 = conditionModel~currentCondition(camera, .CameraConstant~DAY_UNKNOWN, 100, 3)
call assertEqual 'first shifted state', .CameraConstant~CONDITION_SHIFTED, condition1~state
call assertEqual 'first shifted phase emerging', .CameraConstant~CONDITION_PHASE_EMERGING, condition1~persistencePhase
call assertEqual 'first shifted streak', 1, condition1~shiftedStreak

/* Re-reading the same instant must not manufacture persistence. */
condition1Again = conditionModel~currentCondition(camera, .CameraConstant~DAY_UNKNOWN, 100, 3)
call assertEqual 'same instant still emerging', .CameraConstant~CONDITION_PHASE_EMERGING, condition1Again~persistencePhase
call assertEqual 'same instant streak unchanged', 1, condition1Again~shiftedStreak

assessment2 = .CameraClipAssessment~new('shift2', 102, .CameraConstant~DAY_UNKNOWN)
metric2 = .CameraMetricAssessment~new('TRACK_RATE', 0, 0, 5.2, 6, .CameraConstant~BASELINE_ELEVATED, 'ALL')
assessment2~addMetric(metric2)
observedCount = conditionModel~observeAssessment(assessment2, 102)
condition2 = conditionModel~currentCondition(camera, .CameraConstant~DAY_UNKNOWN, 102, 3)
call assertEqual 'second shifted still emerging', .CameraConstant~CONDITION_PHASE_EMERGING, condition2~persistencePhase
call assertEqual 'second shifted streak', 2, condition2~shiftedStreak

assessment3 = .CameraClipAssessment~new('shift3', 104, .CameraConstant~DAY_UNKNOWN)
metric3 = .CameraMetricAssessment~new('TRACK_RATE', 0, 0, 4.8, 6, .CameraConstant~BASELINE_ELEVATED, 'ALL')
assessment3~addMetric(metric3)
observedCount = conditionModel~observeAssessment(assessment3, 104)
condition3 = conditionModel~currentCondition(camera, .CameraConstant~DAY_UNKNOWN, 104, 3)
call assertEqual 'third shifted persistent', .CameraConstant~CONDITION_PHASE_PERSISTENT, condition3~persistencePhase
call assertEqual 'persistent shifted streak', 3, condition3~shiftedStreak

/* Recovery requires consecutive expected observations after persistence. */
assessment4 = .CameraClipAssessment~new('recover1', 106, .CameraConstant~DAY_UNKNOWN)
metric4 = .CameraMetricAssessment~new('TRACK_RATE', 0, 0, 0.1, 6, .CameraConstant~BASELINE_WITHIN, 'ALL')
assessment4~addMetric(metric4)
observedCount = conditionModel~observeAssessment(assessment4, 106)
condition4 = conditionModel~currentCondition(camera, .CameraConstant~DAY_UNKNOWN, 106, 3)
call assertEqual 'first expected state', .CameraConstant~CONDITION_EXPECTED, condition4~state
call assertEqual 'first expected recovering', .CameraConstant~CONDITION_PHASE_RECOVERING, condition4~persistencePhase
call assertEqual 'first expected streak', 1, condition4~expectedStreak

assessment5 = .CameraClipAssessment~new('recover2', 108, .CameraConstant~DAY_UNKNOWN)
metric5 = .CameraMetricAssessment~new('TRACK_RATE', 0, 0, -0.1, 6, .CameraConstant~BASELINE_WITHIN, 'ALL')
assessment5~addMetric(metric5)
observedCount = conditionModel~observeAssessment(assessment5, 108)
condition5 = conditionModel~currentCondition(camera, .CameraConstant~DAY_UNKNOWN, 108, 3)
call assertEqual 'second expected stable', .CameraConstant~CONDITION_PHASE_STABLE, condition5~persistencePhase
call assertEqual 'second expected streak', 2, condition5~expectedStreak

/* A one-sample spike which immediately clears never becomes persistent/recovering. */
spikeModel = .CameraCurrentConditionModel~new(1, 4, 1.0, 2.5, 4.0, 2, 2.0, 3, 3, 2)
spikeAssessment = .CameraClipAssessment~new('spike', 200, .CameraConstant~DAY_UNKNOWN)
spikeMetric = .CameraMetricAssessment~new('EVENT_RATE', 0, 0, 5.5, 6, .CameraConstant~BASELINE_ELEVATED, 'ALL')
spikeAssessment~addMetric(spikeMetric)
observedCount = spikeModel~observeAssessment(spikeAssessment, 200)
spikeCondition = spikeModel~currentCondition(camera, .CameraConstant~DAY_UNKNOWN, 200, 3)
call assertEqual 'spike emerging', .CameraConstant~CONDITION_PHASE_EMERGING, spikeCondition~persistencePhase

clearAssessment = .CameraClipAssessment~new('clear', 202, .CameraConstant~DAY_UNKNOWN)
clearMetric = .CameraMetricAssessment~new('EVENT_RATE', 0, 0, 0.0, 6, .CameraConstant~BASELINE_WITHIN, 'ALL')
clearAssessment~addMetric(clearMetric)
observedCount = spikeModel~observeAssessment(clearAssessment, 202)
clearCondition = spikeModel~currentCondition(camera, .CameraConstant~DAY_UNKNOWN, 202, 3)
call assertEqual 'cleared spike stable', .CameraConstant~CONDITION_PHASE_STABLE, clearCondition~persistencePhase

emptyModel = .CameraCurrentConditionModel~new
emptyCondition = emptyModel~currentCondition(camera, .CameraConstant~DAY_UNKNOWN, 300, 3)
call assertEqual 'empty raw insufficient', .CameraConstant~CONDITION_INSUFFICIENT, emptyCondition~state
call assertEqual 'empty phase insufficient', .CameraConstant~CONDITION_PHASE_INSUFFICIENT, emptyCondition~persistencePhase

say '  persistent streak:' condition3~shiftedStreak
say '  recovery streak:  ' condition5~expectedStreak
say 'CAMERA CURRENT PERSISTENCE SMOKE: OK'
exit 0

assertEqual: procedure
  use arg label, expected, actual
  if expected == actual then return .true
  say 'ASSERT FAILED:' label
  say '  expected:' expected
  say '  actual:  ' actual
  exit 1

::requires 'CameraCore.cls'
