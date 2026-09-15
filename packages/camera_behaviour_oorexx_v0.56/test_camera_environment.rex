/* test_camera_environment.rex - environment-conditioned observation and clip baselines */
say 'CAMERA ENVIRONMENT SMOKE START'

environmentModel = .CameraEnvironmentModel~new
box = .CameraBox~new('E1', 100, 100, 80, 50)
shadowObservation = .CameraObservation~new((15 * 3600) + (15 * 60), box, 0.35, 0.12)

/* Same raw change: diffuse daylight sees moving structure; hard-shadow regime sees light change. */
diffuseType = environmentModel~classifyObservation(shadowObservation, .CameraConstant~ENV_DAY_DIFFUSE)
shadowType = environmentModel~classifyObservation(shadowObservation, .CameraConstant~ENV_DAY_DIRECT_SHADOW)
call assertEqual .CameraConstant~CHANGE_MIXED, diffuseType, 'diffuse regime retains structural candidate'
call assertEqual .CameraConstant~CHANGE_PHOTOMETRIC, shadowType, 'hard-shadow regime suppresses false mover'

/* Background observations can raise an environment profile threshold without touching behaviour. */
shadowProfile = environmentModel~profileFor(.CameraConstant~ENV_DAY_DIRECT_SHADOW)
do calibrationIndex = 1 to 5
  calibrationBox = .CameraBox~new('C' || calibrationIndex, 0, 0, 100, 100)
  calibrationObservation = .CameraObservation~new(1000 + calibrationIndex, calibrationBox, 0.30 + (calibrationIndex / 100), 0.12 + (calibrationIndex / 1000))
  learnedCount = shadowProfile~observeBackgroundObservation(calibrationObservation)
end
call assertTrue shadowProfile~structuralThreshold >= 0.16, 'shadow structural threshold retained or learned upward'
call assertTrue shadowProfile~backgroundStructure~sampleCount = 5, 'background calibration retained'

camera = .CameraModel~new('CAM-ENV', 640, 360)
camera~behaviour~addWindow(.CameraBehaviourWindow~new((15 * 3600) + (15 * 60), 45 * 60))

/* Behaviour baseline is shared by time even when illumination regime differs. */
do sampleIndex = 1 to 6
  diffuseSummary = makeSummary('d-' || sampleIndex, (15 * 3600) + (15 * 60) - 30, .CameraConstant~ENV_DAY_DIFFUSE, 10, 1 + (sampleIndex // 2))
  shadowSummary = makeSummary('s-' || sampleIndex, (15 * 3600) + (15 * 60) - 30, .CameraConstant~ENV_DAY_DIRECT_SHADOW, 10, 20 + sampleIndex)
  learnedDiffuse = .CameraClipComparator~learnSummary(camera, diffuseSummary)
  learnedShadow = .CameraClipComparator~learnSummary(camera, shadowSummary)
end

currentShadow = makeSummary('shadow-current', (15 * 3600) + (15 * 60) - 30, .CameraConstant~ENV_DAY_DIRECT_SHADOW, 10, 23)
shadowAssessment = .CameraClipComparator~assess(camera, currentShadow, 3, 2.5)
call assertEqual .CameraConstant~BASELINE_WITHIN, shadowAssessment~metric('TRACK_RATE')~state, '15:15 behaviour shared across illumination regimes'
call assertEqual .CameraConstant~BASELINE_WITHIN, shadowAssessment~metric('PHOTOMETRIC_RATE')~state, 'high photometric rate ordinary for shadow regime'

sameLightDiffuse = makeSummary('diffuse-current', (15 * 3600) + (15 * 60) - 30, .CameraConstant~ENV_DAY_DIFFUSE, 10, 23)
diffuseAssessment = .CameraClipComparator~assess(camera, sameLightDiffuse, 3, 2.5)
call assertEqual .CameraConstant~BASELINE_WITHIN, diffuseAssessment~metric('TRACK_RATE')~state, 'same behavioural rate still ordinary in diffuse daylight'
call assertEqual .CameraConstant~BASELINE_ELEVATED, diffuseAssessment~metric('PHOTOMETRIC_RATE')~state, 'shadow-like photometric rate unusual in diffuse regime'

/* Clip processor must apply the clip environment before classifying observations. */
clip = .CameraImportedClip~new('shadow-clip', (15 * 3600) + (15 * 60), 2, .CameraConstant~ENV_DAY_DIRECT_SHADOW)
frame = .CameraImportedFrame~new((15 * 3600) + (15 * 60))
frame~addObservation(.CameraObservation~new(frame~timestamp, .CameraBox~new('WALL', 400, 100, 150, 120), 0.35, 0.12))
clip~addFrame(frame)
clipSummary = .CameraClipProcessor~process(camera, clip)
call assertEqual 1, clipSummary~photometricCount, 'shadow wall change counted photometric'
call assertEqual 0, clipSummary~trackCount, 'shadow wall change creates no mover track'
call assertEqual .CameraConstant~ENV_DAY_DIRECT_SHADOW, camera~environment~code, 'clip environment applied to camera observation state'

/* Environment distributions survive persistence independently of time baseline. */
persistPath = 'camera_environment_model.tmp'
call assertEqual 1, .CameraModelPersistence~save(camera, persistPath), 'environment model saved'
restoredCamera = .CameraModelPersistence~load(persistPath)
call assertTrue restoredCamera \== .nil, 'environment model restored'
restoredShadow = .CameraClipComparator~assess(restoredCamera, currentShadow, 3, 2.5)
restoredDiffuse = .CameraClipComparator~assess(restoredCamera, sameLightDiffuse, 3, 2.5)
call assertEqual .CameraConstant~BASELINE_WITHIN, restoredShadow~metric('PHOTOMETRIC_RATE')~state, 'restored shadow baseline retained'
call assertEqual .CameraConstant~BASELINE_ELEVATED, restoredDiffuse~metric('PHOTOMETRIC_RATE')~state, 'restored diffuse baseline retained'
call sysfiledelete persistPath

say '  shadow photometric expected:' shadowAssessment~metric('PHOTOMETRIC_RATE')~expected
say '  diffuse photometric expected:' diffuseAssessment~metric('PHOTOMETRIC_RATE')~expected
say '  shared 15:15 track expected:' shadowAssessment~metric('TRACK_RATE')~expected
say 'CAMERA ENVIRONMENT SMOKE: OK'
exit 0

makeSummary: procedure
  use arg clipId, startSecond, environmentCode, tracks, photometric
  summary = .CameraClipSummary~new(clipId, startSecond, 60, environmentCode)
  summary~trackCount = tracks
  summary~eventCount = tracks
  summary~moverObservationCount = tracks * 4
  summary~interactionCount = 0
  summary~deviationCount = 0
  summary~stopCount = 0
  summary~photometricCount = photometric
  summary~directionCounts[.CameraConstant~DIRECTION_DOWN] = tracks
  return summary

assertEqual: procedure
  use arg expected, actual, message
  if expected \= actual then do
    say 'ASSERT EQUAL FAILED:' message 'expected='expected 'actual='actual
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
