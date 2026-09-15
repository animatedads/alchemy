/* Complete materialized Camera state snapshot tests for CameraCore.cls */

say 'CAMERA MATERIALIZED STATE SMOKE START'

camera = .CameraModel~new('CAMMAT', 640, 360)
model = camera~currentConditionModel
model~windowSeconds = 1
model~persistenceMinimum = 2
model~recoveryMinimum = 1

/* Build and close one regime so a learned regime class exists. */
call addMetricAssessment model, 'a1', 100, 'TRACK_RATE', 5.0, .CameraConstant~BASELINE_ELEVATED
c1 = model~currentCondition(camera, .CameraConstant~DAY_UNKNOWN, 100, 3)
call addMetricAssessment model, 'a2', 101, 'TRACK_RATE', 5.8, .CameraConstant~BASELINE_ELEVATED
c2 = model~currentCondition(camera, .CameraConstant~DAY_UNKNOWN, 101, 3)
call addMetricAssessment model, 'r1', 102, 'TRACK_RATE', 0.0, .CameraConstant~BASELINE_WITHIN
c3 = model~currentCondition(camera, .CameraConstant~DAY_UNKNOWN, 102, 3)

call assertEqual 'one completed regime', 1, model~completedRegimes~items
closed = model~completedRegimes[1]
call assertTrue 'closed regime classified', closed~classId \= ''
call assertEqual 'one regime class learned', 1, model~regimeClasses~items

/* Open another persistent regime so active state is present too. */
call addMetricAssessment model, 'b1', 200, 'INTERACTION_RATE', 5.2, .CameraConstant~BASELINE_ELEVATED
c4 = model~currentCondition(camera, .CameraConstant~DAY_UNKNOWN, 200, 3)
call addMetricAssessment model, 'b2', 201, 'INTERACTION_RATE', 6.1, .CameraConstant~BASELINE_ELEVATED
currentCondition = model~currentCondition(camera, .CameraConstant~DAY_UNKNOWN, 201, 3)
call assertTrue 'active regime exists', model~activeRegime \== .nil

snapshot = camera~materializedState(currentCondition)
canonicalBefore = snapshot~canonicalText

call assertEqual 'snapshot version', .CameraConstant~MATERIALIZED_STATE_SNAPSHOT_VERSION, snapshot~version
call assertTrue 'condition snapshot present', snapshot~condition \== .nil
call assertTrue 'active regime snapshot present', snapshot~activeRegime \== .nil
call assertEqual 'one completed regime snapshotted', 1, snapshot~completedRegimes~items
call assertEqual 'one regime class snapshotted', 1, snapshot~regimeClasses~items
call assertEqual 'active id agrees with condition', currentCondition~activeRegimeId, snapshot~activeRegime~id
call assertEqual 'closed class id retained', closed~classId, snapshot~completedRegimes[1]~classId

classSnapshot = snapshot~regimeClassForSignature(closed~signatureKey)
call assertTrue 'class lookup in snapshot works', classSnapshot \== .nil
call assertEqual 'class id retained', closed~classId, classSnapshot~id

/* Mutate live Camera state after materialization. Frozen state must not move. */
currentCondition~strongestMetricZ = 99
model~activeRegime~peakMetricZ = 88
closed~peakMetricZ = 77
liveClass = model~regimeClassForSignature(closed~signatureKey)
liveClass~sampleCount = 42

call assertTrue 'live mutation happened', model~activeRegime~peakMetricZ = 88
call assertTrue 'frozen active regime did not move', snapshot~activeRegime~peakMetricZ \= 88
call assertTrue 'frozen completed regime did not move', snapshot~completedRegimes[1]~peakMetricZ \= 77
call assertTrue 'frozen class did not move', classSnapshot~sampleCount \= 42
call assertEqual 'canonical identity stable after source mutation', canonicalBefore, snapshot~canonicalText

/* Returned collections are copies, so callers cannot mutate snapshot membership. */
completedCopy = snapshot~completedRegimes
completedCopy~empty
call assertEqual 'completed collection remains frozen', 1, snapshot~completedRegimes~items

classCopy = snapshot~regimeClasses
classCopy~empty
call assertEqual 'class collection remains frozen', 1, snapshot~regimeClasses~items

say '  canonical bytes:' length(canonicalBefore)
say 'CAMERA MATERIALIZED STATE SMOKE: OK'
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
