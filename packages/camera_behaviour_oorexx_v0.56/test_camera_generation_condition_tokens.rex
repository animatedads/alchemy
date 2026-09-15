/* Condition-memory, event-grammar and token-dictionary generation freeze tests. */

say 'CAMERA GENERATION CONDITION TOKEN SMOKE START'

camera = .CameraModel~new('CAMCONDGEN', 640, 360)
conditionModel = camera~currentConditionModel
conditionModel~windowSeconds = 1
conditionModel~persistenceMinimum = 2
conditionModel~recoveryMinimum = 1

/* Allocate a compact-stream dictionary before publication. */
routeToken = camera~tokenDictionary~tokenFor('ROUTE:R1')
zoneToken = camera~tokenDictionary~tokenFor('ZONE:Z1')
episodeToken = camera~tokenDictionary~tokenFor('EPISODE:EP1')
call assertEqual 'three live tokens', 3, camera~tokenDictionary~count

/* Build and close one condition regime so the learned regime class exists. */
call addMetricAssessment conditionModel, 's1', 100, 'TRACK_RATE', 5.0, .CameraConstant~BASELINE_ELEVATED
c1 = conditionModel~currentCondition(camera, .CameraConstant~DAY_UNKNOWN, 100, 3)
call addMetricAssessment conditionModel, 's2', 101, 'TRACK_RATE', 6.0, .CameraConstant~BASELINE_ELEVATED
c2 = conditionModel~currentCondition(camera, .CameraConstant~DAY_UNKNOWN, 101, 3)
call addMetricAssessment conditionModel, 'r1', 102, 'TRACK_RATE', 0.0, .CameraConstant~BASELINE_WITHIN
c3 = conditionModel~currentCondition(camera, .CameraConstant~DAY_UNKNOWN, 102, 3)
call assertEqual 'one completed live regime', 1, conditionModel~completedRegimes~items
call assertEqual 'one live regime class', 1, conditionModel~regimeClasses~items
closed = conditionModel~completedRegimes[1]
classId = closed~classId

/* Make event grammar settings visibly non-default before G1. */
camera~eventGrammar~stopDistance = 3.5
camera~eventGrammar~routeDeviationThreshold = 42

g1 = camera~publishGeneration(200)
call assertEqual 'generation v6', '6', g1~version
call assertEqual 'g1 token count', 3, g1~tokenCount
call assertEqual 'g1 route token text', 'ROUTE:R1', g1~tokenDictionary~textForToken(routeToken)
call assertEqual 'g1 route token lookup', routeToken, g1~tokenDictionary~tokenForText('ROUTE:R1')
call assertEqual 'g1 stop threshold', 3.5, g1~eventGrammar~stopDistance
call assertEqual 'g1 route deviation threshold', 42, g1~eventGrammar~routeDeviationThreshold
call assertEqual 'g1 completed condition regime', 1, g1~completedConditionRegimeCount
call assertEqual 'g1 regime class count', 1, g1~conditionRegimeClassCount
call assertTrue 'g1 class addressable', g1~conditionMemory~regimeClass(classId) \== .nil
call assertEqual 'g1 persistence config frozen', 2, g1~conditionMemory~persistenceMinimum

g1Canonical = g1~semanticCanonicalText
g1ClassSamples = g1~conditionMemory~regimeClass(classId)~sampleCount

/* Mutate every newly frozen live surface after G1. */
newToken = camera~tokenDictionary~tokenFor('ROUTE:R2')
camera~eventGrammar~stopDistance = 99
camera~eventGrammar~routeDeviationThreshold = 999
conditionModel~persistenceMinimum = 4

/* Create a second regime of the same class so the live class sample count advances. */
call addMetricAssessment conditionModel, 's3', 200, 'TRACK_RATE', 5.5, .CameraConstant~BASELINE_ELEVATED
c4 = conditionModel~currentCondition(camera, .CameraConstant~DAY_UNKNOWN, 200, 3)
call addMetricAssessment conditionModel, 's4', 201, 'TRACK_RATE', 6.5, .CameraConstant~BASELINE_ELEVATED
c5 = conditionModel~currentCondition(camera, .CameraConstant~DAY_UNKNOWN, 201, 3)
call addMetricAssessment conditionModel, 's5', 202, 'TRACK_RATE', 6.0, .CameraConstant~BASELINE_ELEVATED
c6 = conditionModel~currentCondition(camera, .CameraConstant~DAY_UNKNOWN, 202, 3)
call addMetricAssessment conditionModel, 's6', 203, 'TRACK_RATE', 6.0, .CameraConstant~BASELINE_ELEVATED
c7 = conditionModel~currentCondition(camera, .CameraConstant~DAY_UNKNOWN, 203, 3)
call addMetricAssessment conditionModel, 'r2', 204, 'TRACK_RATE', 0.0, .CameraConstant~BASELINE_WITHIN
c8 = conditionModel~currentCondition(camera, .CameraConstant~DAY_UNKNOWN, 204, 3)
call addMetricAssessment conditionModel, 'r3', 205, 'TRACK_RATE', 0.0, .CameraConstant~BASELINE_WITHIN
c9 = conditionModel~currentCondition(camera, .CameraConstant~DAY_UNKNOWN, 205, 3)
call addMetricAssessment conditionModel, 'r4', 206, 'TRACK_RATE', 0.0, .CameraConstant~BASELINE_WITHIN
c10 = conditionModel~currentCondition(camera, .CameraConstant~DAY_UNKNOWN, 206, 3)
call addMetricAssessment conditionModel, 'r5', 207, 'TRACK_RATE', 0.0, .CameraConstant~BASELINE_WITHIN
c11 = conditionModel~currentCondition(camera, .CameraConstant~DAY_UNKNOWN, 207, 3)

call assertEqual 'g1 token count unchanged', 3, g1~tokenCount
call assertEqual 'g1 has no R2 token', 0, g1~tokenDictionary~tokenForText('ROUTE:R2')
call assertEqual 'g1 stop threshold unchanged', 3.5, g1~eventGrammar~stopDistance
call assertEqual 'g1 route deviation unchanged', 42, g1~eventGrammar~routeDeviationThreshold
call assertEqual 'g1 persistence config unchanged', 2, g1~conditionMemory~persistenceMinimum
call assertEqual 'g1 class samples unchanged', g1ClassSamples, g1~conditionMemory~regimeClass(classId)~sampleCount
call assertEqual 'g1 semantic identity stable', g1Canonical, g1~semanticCanonicalText

/* G2 sees the new decoder vocabulary, grammar settings and condition memory. */
g2 = camera~publishGeneration(300)
call assertEqual 'g2 token count', 4, g2~tokenCount
call assertEqual 'g2 R2 token retained', newToken, g2~tokenDictionary~tokenForText('ROUTE:R2')
call assertEqual 'g2 stop threshold', 99, g2~eventGrammar~stopDistance
call assertEqual 'g2 route deviation threshold', 999, g2~eventGrammar~routeDeviationThreshold
call assertEqual 'g2 persistence config', 4, g2~conditionMemory~persistenceMinimum
call assertTrue 'g2 condition history at least as rich', g2~completedConditionRegimeCount >= g1~completedConditionRegimeCount

say '  G1 tokens/regimes/classes:' g1~tokenCount g1~completedConditionRegimeCount g1~conditionRegimeClassCount
say '  G2 tokens/regimes/classes:' g2~tokenCount g2~completedConditionRegimeCount g2~conditionRegimeClassCount
say 'CAMERA GENERATION CONDITION TOKEN SMOKE: OK'
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
