/* Rolling current-condition / scene-rhythm tests for CameraCore.cls */

say 'CAMERA CURRENT CONDITION SMOKE START'

camera = .CameraModel~new('CAMCOND', 640, 360)
camera~behaviour~addWindow(.CameraBehaviourWindow~new(15 * 60, 45 * 60))
camera~behaviour~addWindow(.CameraBehaviourWindow~new((4 * 3600) + (30 * 60), 45 * 60))

/* Stable transition dictionary: X1 is normal post-midnight rhythm; X2 is rare there. */
x1 = camera~transitionModel~learn('M1', 'M2')
x2 = camera~transitionModel~learn('M2', 'M3')
call assertEqual 'X1 identity', 'X1', x1~id
call assertEqual 'X2 identity', 'X2', x2~id

do sampleIndex = 1 to 24
  observedWeight = camera~behaviour~observeTransition(15 * 60, 'X1')
end
do sampleIndex = 1 to 2
  observedWeight = camera~behaviour~observeTransition(15 * 60, 'X2')
end
/* Different 04:30 rhythm makes the time conditioning independently observable. */
do sampleIndex = 1 to 18
  observedWeight = camera~behaviour~observeTransition((4 * 3600) + (30 * 60), 'X2')
end

conditionModel = .CameraCurrentConditionModel~new(300, 4, 1.0)

do occurrenceIndex = 1 to 6
  occurrence = .CameraMotifTransitionOccurrence~new('X1', 'M1', 'M2', (15 * 60) + occurrenceIndex * 20)
  observedCount = conditionModel~observeOccurrence(occurrence)
end
normalCondition = conditionModel~currentCondition(camera, .CameraConstant~DAY_UNKNOWN, (15 * 60) + 130, 3)
call assertEqual 'normal sample count', 6, normalCondition~transitionCount
call assertEqual 'normal dominant transition', 'X1', normalCondition~dominantTransitionId
call assertNear 'normal dominant share', 1, normalCondition~dominantTransitionShare, 0.0001
call assertEqual 'normal current condition', .CameraConstant~CONDITION_EXPECTED, normalCondition~state

conditionModel~clear
do occurrenceIndex = 1 to 6
  occurrence = .CameraMotifTransitionOccurrence~new('X2', 'M2', 'M3', (15 * 60) + occurrenceIndex * 20)
  observedCount = conditionModel~observeOccurrence(occurrence)
end
shiftedCondition = conditionModel~currentCondition(camera, .CameraConstant~DAY_UNKNOWN, (15 * 60) + 130, 3)
call assertEqual 'shifted sample count', 6, shiftedCondition~transitionCount
call assertEqual 'shifted dominant transition', 'X2', shiftedCondition~dominantTransitionId
call assertTrue 'rare rhythm costs more context bits', shiftedCondition~averageContextSurpriseBits > normalCondition~averageContextSurpriseBits
call assertTrue 'rare rhythm has positive excess surprise', shiftedCondition~excessSurpriseBits > normalCondition~excessSurpriseBits
call assertEqual 'shifted current condition', .CameraConstant~CONDITION_SHIFTED, shiftedCondition~state

/* The same X2 rhythm becomes expected in its learned 04:30 neighbourhood. */
conditionModel~clear
do occurrenceIndex = 1 to 6
  occurrence = .CameraMotifTransitionOccurrence~new('X2', 'M2', 'M3', (4 * 3600) + (30 * 60) + occurrenceIndex * 20)
  observedCount = conditionModel~observeOccurrence(occurrence)
end
nightCondition = conditionModel~currentCondition(camera, .CameraConstant~DAY_UNKNOWN, (4 * 3600) + (30 * 60) + 130, 3)
call assertTrue 'X2 cheaper at its learned time', nightCondition~averageContextSurpriseBits < shiftedCondition~averageContextSurpriseBits
call assertEqual '04:30 X2 expected', .CameraConstant~CONDITION_EXPECTED, nightCondition~state

/* Rolling expiry: only recent transitions remain in the 5-minute state. */
conditionModel~clear
oldOccurrence = .CameraMotifTransitionOccurrence~new('X1', 'M1', 'M2', 100)
newOccurrence = .CameraMotifTransitionOccurrence~new('X1', 'M1', 'M2', 500)
observedCount = conditionModel~observeOccurrence(oldOccurrence)
observedCount = conditionModel~observeOccurrence(newOccurrence)
rollingCondition = conditionModel~currentCondition(camera, .CameraConstant~DAY_UNKNOWN, 500, 3)
call assertEqual 'expired old transition removed', 1, rollingCondition~transitionCount
call assertEqual 'insufficient state after expiry', .CameraConstant~CONDITION_INSUFFICIENT, rollingCondition~state

/* Midnight wrap must retain a recent 23:59 transition at 00:01. */
conditionModel~clear
beforeMidnight = .CameraMotifTransitionOccurrence~new('X1', 'M1', 'M2', 86340)
afterMidnight = .CameraMotifTransitionOccurrence~new('X1', 'M1', 'M2', 60)
observedCount = conditionModel~observeOccurrence(beforeMidnight)
observedCount = conditionModel~observeOccurrence(afterMidnight)
midnightCondition = conditionModel~currentCondition(camera, .CameraConstant~DAY_UNKNOWN, 60, 3)
call assertEqual 'midnight wrap retains recent transition', 2, midnightCondition~transitionCount

say '  normal surprise bits:  ' normalCondition~averageContextSurpriseBits
say '  shifted surprise bits: ' shiftedCondition~averageContextSurpriseBits
say '  normal excess bits:    ' normalCondition~excessSurpriseBits
say '  shifted excess bits:   ' shiftedCondition~excessSurpriseBits
say 'CAMERA CURRENT CONDITION SMOKE: OK'
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
