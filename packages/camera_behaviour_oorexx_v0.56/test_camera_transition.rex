/* Motif transition grammar/time/day conditioning tests for CameraCore.cls */

say 'CAMERA TRANSITION SMOKE START'

camera = .CameraModel~new('CAMTRANS', 640, 360)
camera~behaviour~addWindow(.CameraBehaviourWindow~new(15 * 60, 45 * 60))
camera~behaviour~addWindow(.CameraBehaviourWindow~new((4 * 3600) + (30 * 60), 45 * 60))

/* Give the motif dictionary stable source/target identities. */
m1 = camera~motifModel~learnSequence('A>B>C')
m1 = camera~motifModel~learnSequence('A>B>C')
m2 = camera~motifModel~learnSequence('D>E>F')
m2 = camera~motifModel~learnSequence('D>E>F')
m3 = camera~motifModel~learnSequence('G>H>I')
m3 = camera~motifModel~learnSequence('G>H>I')
call assertEqual 'M1 id', 'M1', camera~motifModel~motifForSequence('A>B>C')~id
call assertEqual 'M2 id', 'M2', camera~motifModel~motifForSequence('D>E>F')~id
call assertEqual 'M3 id', 'M3', camera~motifModel~motifForSequence('G>H>I')~id

/* Summary order learns M1->M2 and M2->M3, not a giant M1/M2/M3 symbol. */
summary = .CameraClipSummary~new('TRANSITION-0015', 15 * 60, 60, .CameraConstant~ENV_NIGHT_ARTIFICIAL, .CameraConstant~DAY_WEEKEND)
call addMotif summary, 'M1', (15 * 60) + 5
call addMotif summary, 'M2', (15 * 60) + 20
call addMotif summary, 'M3', (15 * 60) + 45
occurrences = camera~transitionModel~recogniseAndLearnSummary(summary)
call assertEqual 'two adjacent transitions', 2, occurrences~items
call assertEqual 'first transition id', 'X1', occurrences[1]~transitionId
call assertEqual 'first transition source', 'M1', occurrences[1]~fromMotifId
call assertEqual 'first transition target', 'M2', occurrences[1]~toMotifId
call assertEqual 'second transition id', 'X2', occurrences[2]~transitionId
call assertEqual 'summary transition count', 2, summary~transitionCount

/* Repeat support must reuse the same identity. */
repeatSummary = .CameraClipSummary~new('TRANSITION-REPEAT', 15 * 60, 60, .CameraConstant~ENV_NIGHT_ARTIFICIAL, .CameraConstant~DAY_WEEKEND)
call addMotif repeatSummary, 'M1', (15 * 60) + 5
call addMotif repeatSummary, 'M2', (15 * 60) + 20
repeatOccurrences = camera~transitionModel~recogniseAndLearnSummary(repeatSummary)
call assertEqual 'known transition reused', 'X1', repeatOccurrences[1]~transitionId
call assertEqual 'X1 support incremented', 2, camera~transitionModel~transitionForId('X1')~sampleCount

/* Time-of-day model: X1 belongs around 00:15, X2 around 04:30. */
do sampleIndex = 1 to 6
  observedWeight = camera~behaviour~observeTransition(15 * 60, 'X1')
  observedWeight = camera~behaviour~observeTransition((4 * 3600) + (30 * 60), 'X2')
end
vocabularySize = camera~transitionModel~transitionCount + 1
bits0015 = camera~behaviour~transitionDescriptionBits(15 * 60, 'X1', vocabularySize)
bits0430 = camera~behaviour~transitionDescriptionBits((4 * 3600) + (30 * 60), 'X1', vocabularySize)
call assertTrue 'X1 cheaper at learned time', bits0015 < bits0430

/* Weekend learns X1, weekday learns X2 at the same clock time. */
do sampleIndex = 1 to 5
  observedWeight = camera~calendarBehaviour~observeTransition(.CameraConstant~DAY_WEEKEND, camera~behaviour, 15 * 60, 'X1')
  observedCount = camera~calendarBehaviour~observeSummary(.CameraConstant~DAY_WEEKEND)
  observedWeight = camera~calendarBehaviour~observeTransition(.CameraConstant~DAY_WEEKDAY, camera~behaviour, 15 * 60, 'X2')
  observedCount = camera~calendarBehaviour~observeSummary(.CameraConstant~DAY_WEEKDAY)
end
weekendBits = camera~calendarBehaviour~transitionDescriptionBits(.CameraConstant~DAY_WEEKEND, camera~behaviour, 15 * 60, 'X1', vocabularySize, 3)
weekdayBits = camera~calendarBehaviour~transitionDescriptionBits(.CameraConstant~DAY_WEEKDAY, camera~behaviour, 15 * 60, 'X1', vocabularySize, 3)
call assertTrue 'X1 cheaper in weekend context', weekendBits < weekdayBits

/* Sparse day context falls back to all-days. */
sparseCamera = .CameraModel~new('CAMSPARSETRANS', 640, 360)
sparseCamera~behaviour~addWindow(.CameraBehaviourWindow~new(15 * 60, 45 * 60))
spTransition = sparseCamera~transitionModel~learn('M1', 'M2')
do sampleIndex = 1 to 4
  observedWeight = sparseCamera~behaviour~observeTransition(15 * 60, 'X1')
end
observedWeight = sparseCamera~calendarBehaviour~observeTransition(.CameraConstant~DAY_WEEKEND, sparseCamera~behaviour, 15 * 60, 'X1')
observedCount = sparseCamera~calendarBehaviour~observeSummary(.CameraConstant~DAY_WEEKEND)
baseBits = sparseCamera~behaviour~transitionDescriptionBits(15 * 60, 'X1', 2)
fallbackBits = sparseCamera~calendarBehaviour~transitionDescriptionBits(.CameraConstant~DAY_WEEKEND, sparseCamera~behaviour, 15 * 60, 'X1', 2, 3)
call assertNear 'sparse transition context falls back', baseBits, fallbackBits, 0.0001

/* Clip assessment exposes transition surprise separately from motif surprise. */
assessWeekend = .CameraClipSummary~new('ASSESS-WEEKEND', 15 * 60, 60, .CameraConstant~ENV_NIGHT_ARTIFICIAL, .CameraConstant~DAY_WEEKEND)
call addTransition assessWeekend, 'X1', 'M1', 'M2', 15 * 60
weekendAssessment = .CameraClipComparator~assess(camera, assessWeekend, 3, 2.5)
assessWeekday = .CameraClipSummary~new('ASSESS-WEEKDAY', 15 * 60, 60, .CameraConstant~ENV_NIGHT_ARTIFICIAL, .CameraConstant~DAY_WEEKDAY)
call addTransition assessWeekday, 'X1', 'M1', 'M2', 15 * 60
weekdayAssessment = .CameraClipComparator~assess(camera, assessWeekday, 3, 2.5)
call assertTrue 'assessment keeps transition context difference', weekendAssessment~averageTransitionDescriptionBits < weekdayAssessment~averageTransitionDescriptionBits

/* Persistence retains transition definitions and conditioned weights. */
path = 'camera_transition_test.model'
saved = .CameraModelPersistence~save(camera, path)
restored = .CameraModelPersistence~load(path)
call assertEqual 'transition dictionary survives', 2, restored~transitionModel~transitionCount
call assertEqual 'X1 source survives', 'M1', restored~transitionModel~transitionForId('X1')~fromMotifId
call assertEqual 'X1 target survives', 'M2', restored~transitionModel~transitionForId('X1')~toMotifId
restoredWeekendBits = restored~calendarBehaviour~transitionDescriptionBits(.CameraConstant~DAY_WEEKEND, restored~behaviour, 15 * 60, 'X1', vocabularySize, 3)
restoredWeekdayBits = restored~calendarBehaviour~transitionDescriptionBits(.CameraConstant~DAY_WEEKDAY, restored~behaviour, 15 * 60, 'X1', vocabularySize, 3)
call assertNear 'weekend transition cost survives reload', weekendBits, restoredWeekendBits, 0.0001
call assertNear 'weekday transition cost survives reload', weekdayBits, restoredWeekdayBits, 0.0001
call sysfiledelete path

say '  X1 00:15 bits:          ' bits0015
say '  X1 04:30 bits:          ' bits0430
say '  X1 weekend 00:15 bits:  ' weekendBits
say '  X1 weekday 00:15 bits:  ' weekdayBits
say 'CAMERA TRANSITION SMOKE: OK'
exit 0

addMotif: procedure
  use arg summaryObject, motifId, secondOfDay
  motifEncoding = .CameraMotifEncoding~new(motifId, 'test-sequence', .CameraConstant~MOTIF_KNOWN, 100, 20, secondOfDay)
  added = summaryObject~addMotifOccurrence(motifEncoding)
  return

addTransition: procedure
  use arg summaryObject, transitionId, fromMotifId, toMotifId, secondOfDay
  occurrence = .CameraMotifTransitionOccurrence~new(transitionId, fromMotifId, toMotifId, secondOfDay)
  added = summaryObject~addTransitionOccurrence(occurrence)
  return

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
