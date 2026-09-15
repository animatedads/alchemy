/* Recurring current-condition regime classification tests for CameraCore.cls */

say 'CAMERA CURRENT REGIME CLASS SMOKE START'

camera = .CameraModel~new('CAMREGCLASS', 640, 360)
model = .CameraCurrentConditionModel~new(1, 4, 1.0, 2.5, 4.0, 2, 2.0, 3, 2, 1)

/* First sustained positive TRACK_RATE regime creates a new class. */
call runRegime model, camera, 100, 'TRACK_RATE', 5.0, 5.5
call assertEqual 'one completed regime', 1, model~completedRegimes~items
r1 = model~completedRegimes[1]
call assertTrue 'first regime has class', r1~classId \= ''
call assertTrue 'first regime has signature', r1~signatureKey \= ''
call assertEqual 'one regime class', 1, model~regimeClasses~items
class1 = model~regimeClassForSignature(r1~signatureKey)
call assertTrue 'class lookup works', class1 \== .nil
call assertEqual 'first class sample count', 1, class1~sampleCount
call assertEqual 'first class is new', .CameraConstant~CONDITION_REGIME_CLASS_NEW, class1~state

/* Same cause/metric/direction reuses the same learned class. */
call runRegime model, camera, 200, 'TRACK_RATE', 6.0, 6.4
call assertEqual 'two completed regimes', 2, model~completedRegimes~items
r2 = model~completedRegimes[2]
call assertEqual 'same class id reused', r1~classId, r2~classId
call assertEqual 'still one regime class', 1, model~regimeClasses~items
class1b = model~regimeClassForSignature(r2~signatureKey)
call assertEqual 'class now known', .CameraConstant~CONDITION_REGIME_CLASS_KNOWN, class1b~state
call assertEqual 'class sample count two', 2, class1b~sampleCount

/* Opposite direction is structurally a different regime type. */
call runRegime model, camera, 300, 'TRACK_RATE', -5.1, -5.8
call assertEqual 'three completed regimes', 3, model~completedRegimes~items
r3 = model~completedRegimes[3]
call assertTrue 'negative regime gets different class', r3~classId \= r1~classId
call assertEqual 'two regime classes', 2, model~regimeClasses~items

/* Different peak metric also forms a distinct class. */
call runRegime model, camera, 400, 'INTERACTION_RATE', 5.2, 5.9
r4 = model~completedRegimes[4]
call assertTrue 'different metric class differs', r4~classId \= r1~classId
call assertEqual 'three regime classes', 3, model~regimeClasses~items

say '  recurring class:' class1b~compactText
say '  negative class: ' model~regimeClassForSignature(r3~signatureKey)~compactText
say 'CAMERA CURRENT REGIME CLASS SMOKE: OK'
exit 0

runRegime: procedure
  use arg model, camera, startSecond, metricName, firstZ, secondZ
  call addMetricAssessment model, 'a', startSecond, metricName, firstZ, .CameraConstant~BASELINE_ELEVATED
  c1 = model~currentCondition(camera, .CameraConstant~DAY_UNKNOWN, startSecond, 3)
  call addMetricAssessment model, 'b', startSecond + 1, metricName, secondZ, .CameraConstant~BASELINE_ELEVATED
  c2 = model~currentCondition(camera, .CameraConstant~DAY_UNKNOWN, startSecond + 1, 3)
  call assertEqual 'regime became persistent', .CameraConstant~CONDITION_PHASE_PERSISTENT, c2~persistencePhase
  call addMetricAssessment model, 'r', startSecond + 2, metricName, 0.0, .CameraConstant~BASELINE_WITHIN
  c3 = model~currentCondition(camera, .CameraConstant~DAY_UNKNOWN, startSecond + 2, 3)
  call assertEqual 'regime recovered', .CameraConstant~CONDITION_PHASE_STABLE, c3~persistencePhase
  return

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
