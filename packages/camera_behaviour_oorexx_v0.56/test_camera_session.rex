/* test_camera_session.rex - clip/session comparison against overlapping baselines */
say 'CAMERA SESSION SMOKE START'

camera = .CameraModel~new('CAM-SESSION', 640, 360)
camera~behaviour~addWindow(.CameraBehaviourWindow~new(15 * 60, 30 * 60))
camera~behaviour~addWindow(.CameraBehaviourWindow~new((4 * 3600) + (30 * 60), 30 * 60))

/* Around 00:15, ten-ish downhill tracks per minute are ordinary. */
nightCounts = .array~of(8, 9, 10, 11, 12)
nightDown = .array~of(6, 7, 9, 10, 10)
do sampleIndex = 1 to nightCounts~items
  trainingSummary = makeSummary('night-' || sampleIndex, (15 * 60) - 30, nightCounts[sampleIndex], nightDown[sampleIndex], 2, 1)
  learned = .CameraClipComparator~learnSummary(camera, trainingSummary)
end

/* Around 04:30, occupancy is much lower and downhill flow is not dominant. */
quietCounts = .array~of(1, 1, 2, 2, 1)
quietDown = .array~of(0, 0, 0, 1, 0)
do sampleIndex = 1 to quietCounts~items
  trainingSummary = makeSummary('quiet-' || sampleIndex, ((4 * 3600) + (30 * 60)) - 30, quietCounts[sampleIndex], quietDown[sampleIndex], 0, 0)
  learned = .CameraClipComparator~learnSummary(camera, trainingSummary)
end

samePattern0015 = makeSummary('current-0015', (15 * 60) - 30, 10, 9, 2, 1)
assessment0015 = .CameraClipComparator~assess(camera, samePattern0015, 3, 2.5)
track0015 = assessment0015~metric('TRACK_RATE')
down0015 = assessment0015~metric('DIR_DOWN_SHARE')
call assertEqual .CameraConstant~BASELINE_WITHIN, track0015~state, 'ten tracks ordinary at 00:15'
call assertEqual .CameraConstant~BASELINE_WITHIN, down0015~state, 'downhill share ordinary at 00:15'

samePattern0430 = makeSummary('current-0430', ((4 * 3600) + (30 * 60)) - 30, 10, 9, 2, 1)
assessment0430 = .CameraClipComparator~assess(camera, samePattern0430, 3, 2.5)
track0430 = assessment0430~metric('TRACK_RATE')
down0430 = assessment0430~metric('DIR_DOWN_SHARE')
call assertEqual .CameraConstant~BASELINE_ELEVATED, track0430~state, 'same ten tracks unusual at 04:30'
call assertEqual .CameraConstant~BASELINE_ELEVATED, down0430~state, 'same downhill share unusual at 04:30'
call assertTrue abs(track0430~zScore) > abs(track0015~zScore), '04:30 track deviation larger'

/* Photometric activity is an independent environmental signal, not mover count. */
call assertTrue assessment0430~metric('PHOTOMETRIC_RATE') \== .nil, 'photometric metric retained independently'

/* Clip scalar baseline survives camera persistence. */
persistPath = 'camera_session_model.tmp'
call assertEqual 1, .CameraModelPersistence~save(camera, persistPath), 'session baseline saved'
restoredCamera = .CameraModelPersistence~load(persistPath)
call assertTrue restoredCamera \== .nil, 'session baseline restored'
restoredAssessment = .CameraClipComparator~assess(restoredCamera, samePattern0430, 3, 2.5)
call assertEqual .CameraConstant~BASELINE_ELEVATED, restoredAssessment~metric('TRACK_RATE')~state, 'restored baseline still detects 04:30 change'
call assertNear track0430~expected, restoredAssessment~metric('TRACK_RATE')~expected, 0.0001, 'restored expected rate preserved'
call sysfiledelete persistPath

say '  00:15 expected tracks/min:' track0015~expected
say '  00:15 observed tracks/min:' track0015~value
say '  04:30 expected tracks/min:' track0430~expected
say '  04:30 observed tracks/min:' track0430~value
say '  04:30 track z-score:' track0430~zScore
say 'CAMERA SESSION SMOKE: OK'
exit 0

makeSummary: procedure
  use arg clipId, startSecond, tracks, downTracks, interactions, deviations
  summary = .CameraClipSummary~new(clipId, startSecond, 60, .CameraConstant~ENV_NIGHT_ARTIFICIAL)
  summary~trackCount = tracks
  summary~eventCount = tracks + interactions + deviations
  summary~moverObservationCount = tracks * 4
  summary~interactionCount = interactions
  summary~deviationCount = deviations
  summary~stopCount = 0
  summary~photometricCount = 1
  summary~directionCounts[.CameraConstant~DIRECTION_DOWN] = downTracks
  summary~directionCounts[.CameraConstant~DIRECTION_UP] = tracks - downTracks
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
