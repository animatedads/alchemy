/* test_camera_calendar.rex - day-class conditioned baselines with fallback */
say 'CAMERA CALENDAR SMOKE START'

camera = .CameraModel~new('CAM-CALENDAR', 640, 360)
camera~behaviour~addWindow(.CameraBehaviourWindow~new(15 * 60, 45 * 60))

weekdayRates = .array~of(2, 2, 3, 2, 3)
weekendRates = .array~of(9, 10, 11, 10, 12)

do sampleIndex = 1 to weekdayRates~items
  trainingSummary = makeSummary('weekday-' || sampleIndex, weekdayRates[sampleIndex], .CameraConstant~DAY_WEEKDAY)
  learned = .CameraClipComparator~learnSummary(camera, trainingSummary)
end

do sampleIndex = 1 to weekendRates~items
  trainingSummary = makeSummary('weekend-' || sampleIndex, weekendRates[sampleIndex], .CameraConstant~DAY_WEEKEND)
  learned = .CameraClipComparator~learnSummary(camera, trainingSummary)
end

weekendCurrent = makeSummary('weekend-current', 10, .CameraConstant~DAY_WEEKEND)
weekendAssessment = .CameraClipComparator~assess(camera, weekendCurrent, 3, 2.5)
weekendTrack = weekendAssessment~metric('TRACK_RATE')
call assertEqual 'DAY:' || .CameraConstant~DAY_WEEKEND, weekendTrack~baselineContext, 'weekend uses weekend context'
call assertEqual .CameraConstant~BASELINE_WITHIN, weekendTrack~state, 'ten tracks is ordinary weekend midnight behaviour'

weekdayCurrent = makeSummary('weekday-current', 10, .CameraConstant~DAY_WEEKDAY)
weekdayAssessment = .CameraClipComparator~assess(camera, weekdayCurrent, 3, 2.5)
weekdayTrack = weekdayAssessment~metric('TRACK_RATE')
call assertEqual 'DAY:' || .CameraConstant~DAY_WEEKDAY, weekdayTrack~baselineContext, 'weekday uses weekday context'
call assertEqual .CameraConstant~BASELINE_ELEVATED, weekdayTrack~state, 'ten tracks is unusual weekday midnight behaviour'

/* Unknown day class deliberately falls back to the all-days baseline. */
unknownCurrent = makeSummary('unknown-current', 6, .CameraConstant~DAY_UNKNOWN)
unknownAssessment = .CameraClipComparator~assess(camera, unknownCurrent, 3, 2.5)
call assertEqual 'ALL', unknownAssessment~metric('TRACK_RATE')~baselineContext, 'unknown day uses all-days model'

/* A sparse day-class must not overrule a well-supported all-days baseline. */
fallbackCamera = .CameraModel~new('CAM-CALENDAR-FALLBACK', 640, 360)
fallbackCamera~behaviour~addWindow(.CameraBehaviourWindow~new(15 * 60, 45 * 60))
allRates = .array~of(4, 5, 6, 7, 8)
do sampleIndex = 1 to allRates~items
  genericSummary = makeSummary('generic-' || sampleIndex, allRates[sampleIndex], .CameraConstant~DAY_UNKNOWN)
  learned = .CameraClipComparator~learnSummary(fallbackCamera, genericSummary)
end
/* Only two weekend examples: below minimumSupport=3. */
do sampleIndex = 1 to 2
  sparseWeekend = makeSummary('sparse-weekend-' || sampleIndex, 20 + sampleIndex, .CameraConstant~DAY_WEEKEND)
  learned = .CameraClipComparator~learnSummary(fallbackCamera, sparseWeekend)
end
fallbackCurrent = makeSummary('fallback-current', 6, .CameraConstant~DAY_WEEKEND)
fallbackAssessment = .CameraClipComparator~assess(fallbackCamera, fallbackCurrent, 3, 2.5)
fallbackTrack = fallbackAssessment~metric('TRACK_RATE')
call assertEqual 'ALL', fallbackTrack~baselineContext, 'insufficient weekend support falls back to all-days'

/* Day context and its real clip support survive persistence. */
persistPath = 'camera_calendar_model.tmp'
call assertEqual 1, .CameraModelPersistence~save(camera, persistPath), 'calendar model saved'
restoredCamera = .CameraModelPersistence~load(persistPath)
call assertTrue restoredCamera \== .nil, 'calendar model restored'
restoredAssessment = .CameraClipComparator~assess(restoredCamera, weekendCurrent, 3, 2.5)
restoredTrack = restoredAssessment~metric('TRACK_RATE')
call assertEqual 'DAY:' || .CameraConstant~DAY_WEEKEND, restoredTrack~baselineContext, 'restored model retains weekend context'
call assertNear weekendTrack~expected, restoredTrack~expected, 0.0001, 'restored weekend expectation preserved'
call sysfiledelete persistPath

say '  weekday expected tracks/min:' weekdayTrack~expected
say '  weekend expected tracks/min:' weekendTrack~expected
say '  weekend context support:' weekendTrack~support
say 'CAMERA CALENDAR SMOKE: OK'
exit 0

makeSummary: procedure
  use arg clipId, tracks, dayClass
  summary = .CameraClipSummary~new(clipId, (15 * 60) - 30, 60, .CameraConstant~ENV_NIGHT_ARTIFICIAL, dayClass)
  summary~trackCount = tracks
  summary~eventCount = tracks
  summary~moverObservationCount = tracks * 4
  summary~interactionCount = 0
  summary~deviationCount = 0
  summary~stopCount = 0
  summary~photometricCount = 1
  summary~directionCounts[.CameraConstant~DIRECTION_DOWN] = tracks
  return summary

assertEqual: procedure
  use arg expected, actual, message
  if expected \= actual then do
    say 'ASSERT EQUAL FAILED:' message 'expected='expected 'actual='actual
    exit 1
  end
  return 1

assertNear: procedure
  use arg expected, actual, tolerance, message
  if abs(expected - actual) > tolerance then do
    say 'ASSERT NEAR FAILED:' message 'expected='expected 'actual='actual
    exit 1
  end
  return 1

assertTrue: procedure
  use arg condition, message
  if \ condition then do
    say 'ASSERT TRUE FAILED:' message
    exit 1
  end
  return 1

::requires 'CameraCore.cls'
