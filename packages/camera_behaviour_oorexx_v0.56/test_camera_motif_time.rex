/* Motif time/day conditioning tests for CameraCore.cls */

say 'CAMERA MOTIF TIME SMOKE START'

camera = .CameraModel~new('CAMMOTTIME', 640, 360)
camera~behaviour~addWindow(.CameraBehaviourWindow~new(15 * 60, 45 * 60))
camera~behaviour~addWindow(.CameraBehaviourWindow~new((4 * 3600) + (30 * 60), 45 * 60))

seq1 = 'E:' || .CameraConstant~EVENT_ENTER || ':R:R7:Z:Z3>P:EP1>E:' || .CameraConstant~EVENT_EXIT || ':R:R7:Z:Z8'
seq2 = 'E:' || .CameraConstant~EVENT_ENTER || ':R:R2:Z:Z1>E:' || .CameraConstant~EVENT_STOP || ':R:R2:Z:Z4>E:' || .CameraConstant~EVENT_EXIT || ':R:R2:Z:Z9'
learned1 = camera~motifModel~learnSequence(seq1)
learned1 = camera~motifModel~learnSequence(seq1)
learned2 = camera~motifModel~learnSequence(seq2)
learned2 = camera~motifModel~learnSequence(seq2)
call assertEqual 'first motif id', 'M1', camera~motifModel~motifForSequence(seq1)~id
call assertEqual 'second motif id', 'M2', camera~motifModel~motifForSequence(seq2)~id

/* Time-of-day model: M1 belongs around 00:15, M2 around 04:30. */
do sampleIndex = 1 to 6
  observedWeight = camera~behaviour~observeMotif(15 * 60, 'M1')
  observedWeight = camera~behaviour~observeMotif((4 * 3600) + (30 * 60), 'M2')
end
vocabularySize = camera~motifModel~motifCount + 1
bits0015 = camera~behaviour~motifDescriptionBits(15 * 60, 'M1', vocabularySize)
bits0430 = camera~behaviour~motifDescriptionBits((4 * 3600) + (30 * 60), 'M1', vocabularySize)
call assertTrue 'M1 cheaper in learned time neighbourhood', bits0015 < bits0430

/* Calendar context at the same clock time. Weekend learns M1, weekday M2. */
do sampleIndex = 1 to 5
  observedWeight = camera~calendarBehaviour~observeMotif(.CameraConstant~DAY_WEEKEND, camera~behaviour, 15 * 60, 'M1')
  observedCount = camera~calendarBehaviour~observeSummary(.CameraConstant~DAY_WEEKEND)
  observedWeight = camera~calendarBehaviour~observeMotif(.CameraConstant~DAY_WEEKDAY, camera~behaviour, 15 * 60, 'M2')
  observedCount = camera~calendarBehaviour~observeSummary(.CameraConstant~DAY_WEEKDAY)
end
weekendBits = camera~calendarBehaviour~motifDescriptionBits(.CameraConstant~DAY_WEEKEND, camera~behaviour, 15 * 60, 'M1', vocabularySize, 3)
weekdayBits = camera~calendarBehaviour~motifDescriptionBits(.CameraConstant~DAY_WEEKDAY, camera~behaviour, 15 * 60, 'M1', vocabularySize, 3)
call assertTrue 'M1 cheaper in weekend context', weekendBits < weekdayBits

/* Insufficient calendar support must fall back to the all-days time model. */
sparseCamera = .CameraModel~new('CAMSPARSEMOT', 640, 360)
sparseCamera~behaviour~addWindow(.CameraBehaviourWindow~new(15 * 60, 45 * 60))
spMotif = sparseCamera~motifModel~learnSequence(seq1)
spMotif = sparseCamera~motifModel~learnSequence(seq1)
do sampleIndex = 1 to 4
  observedWeight = sparseCamera~behaviour~observeMotif(15 * 60, 'M1')
end
observedWeight = sparseCamera~calendarBehaviour~observeMotif(.CameraConstant~DAY_WEEKEND, sparseCamera~behaviour, 15 * 60, 'M1')
observedCount = sparseCamera~calendarBehaviour~observeSummary(.CameraConstant~DAY_WEEKEND)
baseBits = sparseCamera~behaviour~motifDescriptionBits(15 * 60, 'M1', 2)
fallbackBits = sparseCamera~calendarBehaviour~motifDescriptionBits(.CameraConstant~DAY_WEEKEND, sparseCamera~behaviour, 15 * 60, 'M1', 2, 3)
call assertNear 'sparse day context falls back to all-days', baseBits, fallbackBits, 0.0001

/* Clip-level assessment exposes context-conditioned motif cost. */
summaryWeekend = .CameraClipSummary~new('WEEKEND-MOTIF-0015', 15 * 60, 60, .CameraConstant~ENV_NIGHT_ARTIFICIAL, .CameraConstant~DAY_WEEKEND)
call addMotifToSummary summaryWeekend, 'M1', 15 * 60
assessmentWeekend = .CameraClipComparator~assess(camera, summaryWeekend, 3, 2.5)
summaryWeekday = .CameraClipSummary~new('WEEKDAY-MOTIF-0015', 15 * 60, 60, .CameraConstant~ENV_NIGHT_ARTIFICIAL, .CameraConstant~DAY_WEEKDAY)
call addMotifToSummary summaryWeekday, 'M1', 15 * 60
assessmentWeekday = .CameraClipComparator~assess(camera, summaryWeekday, 3, 2.5)
call assertTrue 'clip assessment retains motif cost difference', assessmentWeekend~averageMotifDescriptionBits < assessmentWeekday~averageMotifDescriptionBits

/* Persistence must retain global and day-context motif weights. */
path = 'camera_motif_time_test.model'
saved = .CameraModelPersistence~save(camera, path)
restored = .CameraModelPersistence~load(path)
restoredWeekendBits = restored~calendarBehaviour~motifDescriptionBits(.CameraConstant~DAY_WEEKEND, restored~behaviour, 15 * 60, 'M1', vocabularySize, 3)
restoredWeekdayBits = restored~calendarBehaviour~motifDescriptionBits(.CameraConstant~DAY_WEEKDAY, restored~behaviour, 15 * 60, 'M1', vocabularySize, 3)
call assertNear 'weekend motif cost survives reload', weekendBits, restoredWeekendBits, 0.0001
call assertNear 'weekday motif cost survives reload', weekdayBits, restoredWeekdayBits, 0.0001
call sysfiledelete path

say '  M1 00:15 bits:          ' bits0015
say '  M1 04:30 bits:          ' bits0430
say '  M1 weekend 00:15 bits:  ' weekendBits
say '  M1 weekday 00:15 bits:  ' weekdayBits
say 'CAMERA MOTIF TIME SMOKE: OK'
exit 0

addMotifToSummary: procedure
  use arg summaryObject, motifId, secondOfDay
  motifEncoding = .CameraMotifEncoding~new(motifId, 'test-sequence', .CameraConstant~MOTIF_KNOWN, 100, 20, secondOfDay)
  added = summaryObject~addMotifOccurrence(motifEncoding)
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
