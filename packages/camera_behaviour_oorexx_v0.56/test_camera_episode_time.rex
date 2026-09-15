/* Episode time/day conditioning tests for CameraCore.cls */

say 'CAMERA EPISODE TIME SMOKE START'

camera = .CameraModel~new('CAMEPTIME', 640, 360)
camera~behaviour~addWindow(.CameraBehaviourWindow~new(15 * 60, 45 * 60))
camera~behaviour~addWindow(.CameraBehaviourWindow~new((4 * 3600) + (30 * 60), 45 * 60))

seq1 = .CameraConstant~EVENT_APPROACH || ',' || .CameraConstant~EVENT_CLOSE || ',' || .CameraConstant~EVENT_SEPARATE
seq2 = .CameraConstant~EVENT_APPROACH || ',' || .CameraConstant~EVENT_SEPARATE
learned1 = camera~episodeModel~learnSequence(seq1)
learned1 = camera~episodeModel~learnSequence(seq1)
learned2 = camera~episodeModel~learnSequence(seq2)
learned2 = camera~episodeModel~learnSequence(seq2)
call assertEqual 'first episode id', 'EP1', camera~episodeModel~episodeForSequence(seq1)~id
call assertEqual 'second episode id', 'EP2', camera~episodeModel~episodeForSequence(seq2)~id

/* Time-of-day model: EP1 belongs around 00:15, EP2 around 04:30. */
do sampleIndex = 1 to 6
  observedWeight = camera~behaviour~observeEpisode(15 * 60, 'EP1')
  observedWeight = camera~behaviour~observeEpisode((4 * 3600) + (30 * 60), 'EP2')
end
vocabularySize = camera~episodeModel~episodeCount + 1
bits0015 = camera~behaviour~episodeDescriptionBits(15 * 60, 'EP1', vocabularySize)
bits0430 = camera~behaviour~episodeDescriptionBits((4 * 3600) + (30 * 60), 'EP1', vocabularySize)
call assertTrue 'EP1 cheaper in learned time neighbourhood', bits0015 < bits0430

/* Calendar context at the same clock time. Weekend learns EP1, weekday EP2. */
do sampleIndex = 1 to 5
  observedWeight = camera~calendarBehaviour~observeEpisode(.CameraConstant~DAY_WEEKEND, camera~behaviour, 15 * 60, 'EP1')
  observedCount = camera~calendarBehaviour~observeSummary(.CameraConstant~DAY_WEEKEND)
  observedWeight = camera~calendarBehaviour~observeEpisode(.CameraConstant~DAY_WEEKDAY, camera~behaviour, 15 * 60, 'EP2')
  observedCount = camera~calendarBehaviour~observeSummary(.CameraConstant~DAY_WEEKDAY)
end
weekendBits = camera~calendarBehaviour~episodeDescriptionBits(.CameraConstant~DAY_WEEKEND, camera~behaviour, 15 * 60, 'EP1', vocabularySize, 3)
weekdayBits = camera~calendarBehaviour~episodeDescriptionBits(.CameraConstant~DAY_WEEKDAY, camera~behaviour, 15 * 60, 'EP1', vocabularySize, 3)
call assertTrue 'EP1 cheaper in weekend context', weekendBits < weekdayBits

/* Insufficient calendar support must fall back to the all-days time model. */
sparseCamera = .CameraModel~new('CAMSPARSEEP', 640, 360)
sparseCamera~behaviour~addWindow(.CameraBehaviourWindow~new(15 * 60, 45 * 60))
spEpisode = sparseCamera~episodeModel~learnSequence(seq1)
spEpisode = sparseCamera~episodeModel~learnSequence(seq1)
do sampleIndex = 1 to 4
  observedWeight = sparseCamera~behaviour~observeEpisode(15 * 60, 'EP1')
end
observedWeight = sparseCamera~calendarBehaviour~observeEpisode(.CameraConstant~DAY_WEEKEND, sparseCamera~behaviour, 15 * 60, 'EP1')
observedCount = sparseCamera~calendarBehaviour~observeSummary(.CameraConstant~DAY_WEEKEND)
baseBits = sparseCamera~behaviour~episodeDescriptionBits(15 * 60, 'EP1', 2)
fallbackBits = sparseCamera~calendarBehaviour~episodeDescriptionBits(.CameraConstant~DAY_WEEKEND, sparseCamera~behaviour, 15 * 60, 'EP1', 2, 3)
call assertNear 'sparse day context falls back to all-days', baseBits, fallbackBits, 0.0001

/* Clip-level assessment exposes context-conditioned episode cost. */
summaryWeekend = .CameraClipSummary~new('WEEKEND-0015', 15 * 60, 60, .CameraConstant~ENV_NIGHT_ARTIFICIAL, .CameraConstant~DAY_WEEKEND)
call addEpisodeToSummary summaryWeekend, 'EP1', 15 * 60
assessmentWeekend = .CameraClipComparator~assess(camera, summaryWeekend, 3, 2.5)
summaryWeekday = .CameraClipSummary~new('WEEKDAY-0015', 15 * 60, 60, .CameraConstant~ENV_NIGHT_ARTIFICIAL, .CameraConstant~DAY_WEEKDAY)
call addEpisodeToSummary summaryWeekday, 'EP1', 15 * 60
assessmentWeekday = .CameraClipComparator~assess(camera, summaryWeekday, 3, 2.5)
call assertTrue 'clip assessment retains episode cost difference', assessmentWeekend~averageEpisodeDescriptionBits < assessmentWeekday~averageEpisodeDescriptionBits

/* Persistence must retain global and day-context episode weights. */
path = 'camera_episode_time_test.model'
saved = .CameraModelPersistence~save(camera, path)
restored = .CameraModelPersistence~load(path)
restoredWeekendBits = restored~calendarBehaviour~episodeDescriptionBits(.CameraConstant~DAY_WEEKEND, restored~behaviour, 15 * 60, 'EP1', vocabularySize, 3)
restoredWeekdayBits = restored~calendarBehaviour~episodeDescriptionBits(.CameraConstant~DAY_WEEKDAY, restored~behaviour, 15 * 60, 'EP1', vocabularySize, 3)
call assertNear 'weekend episode cost survives reload', weekendBits, restoredWeekendBits, 0.0001
call assertNear 'weekday episode cost survives reload', weekdayBits, restoredWeekdayBits, 0.0001
call sysfiledelete path

say '  EP1 00:15 bits:          ' bits0015
say '  EP1 04:30 bits:          ' bits0430
say '  EP1 weekend 00:15 bits:  ' weekendBits
say '  EP1 weekday 00:15 bits:  ' weekdayBits
say 'CAMERA EPISODE TIME SMOKE: OK'
exit 0

addEpisodeToSummary: procedure
  use arg summaryObject, episodeId, secondOfDay
  e1 = .CameraEvent~new('X1', .CameraConstant~EVENT_APPROACH, secondOfDay, 'TA', 'TB')
  e1~episodeId = episodeId
  e2 = .CameraEvent~new('X2', .CameraConstant~EVENT_CLOSE, secondOfDay + 1, 'TA', 'TB')
  e2~episodeId = episodeId
  e3 = .CameraEvent~new('X3', .CameraConstant~EVENT_SEPARATE, secondOfDay + 2, 'TA', 'TB')
  e3~episodeId = episodeId
  added = summaryObject~addEvent(e1)
  added = summaryObject~addEvent(e2)
  added = summaryObject~addEvent(e3)
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
