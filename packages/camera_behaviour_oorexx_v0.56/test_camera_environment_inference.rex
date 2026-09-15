/* test_camera_environment_inference.rex - automatic environment-state inference */
say 'CAMERA ENVIRONMENT INFERENCE SMOKE START'

model = .CameraEnvironmentModel~new

/* Prototype inference works before any camera-specific signature learning. */
nightSignature = .CameraEnvironmentSignature~new(0.22, 0.36, 0.18, 0.08, 0.09)
nightInference = model~infer(nightSignature, (4 * 3600) + (30 * 60))
call assertEqual .CameraConstant~ENV_NIGHT_ARTIFICIAL, nightInference~code, '04:30 night prototype inferred'
call assertEqual .CameraConstant~ENV_INFERENCE_PROTOTYPE, nightInference~method, 'prototype method reported before training'

shadowSignature = .CameraEnvironmentSignature~new(0.61, 0.56, 0.48, 0.31, 0.11)
shadowInference = model~infer(shadowSignature, (15 * 3600) + (15 * 60))
call assertEqual .CameraConstant~ENV_DAY_DIRECT_SHADOW, shadowInference~code, '15:15 hard-shadow prototype inferred'

diffuseSignature = .CameraEnvironmentSignature~new(0.68, 0.24, 0.13, 0.26, 0.05)
diffuseInference = model~infer(diffuseSignature, (12 * 3600))
call assertEqual .CameraConstant~ENV_DAY_DIFFUSE, diffuseInference~code, '12:00 diffuse-day prototype inferred'

/* Clock time is only a weak prior, but must resolve an otherwise ambiguous night/day signature. */
ambiguousSignature = .CameraEnvironmentSignature~new(0.45, 0.30, 0.175, 0.175, 0.07)
earlyInference = model~infer(ambiguousSignature, (4 * 3600) + (30 * 60))
noonInference = model~infer(ambiguousSignature, (12 * 3600))
call assertEqual .CameraConstant~ENV_NIGHT_ARTIFICIAL, earlyInference~code, '04:30 prior resolves ambiguous signature toward night'
call assertEqual .CameraConstant~ENV_DAY_DIFFUSE, noonInference~code, '12:00 prior resolves ambiguous signature toward day'

/* Camera-specific examples supersede prototypes once enough support exists. */
do sampleIndex = 1 to 5
  learnedSignature = .CameraEnvironmentSignature~new(0.48 + (sampleIndex / 1000), 0.68, 0.57, 0.35, 0.13)
  learnedSupport = model~observeSignature(.CameraConstant~ENV_DAY_DIRECT_SHADOW, learnedSignature)
end
customSignature = .CameraEnvironmentSignature~new(0.485, 0.67, 0.56, 0.34, 0.13)
customInference = model~infer(customSignature, (15 * 3600) + (15 * 60))
call assertEqual .CameraConstant~ENV_DAY_DIRECT_SHADOW, customInference~code, 'learned hard-shadow signature inferred'
call assertEqual .CameraConstant~ENV_INFERENCE_PROFILE, customInference~method, 'learned profile method reported'
call assertTrue customInference~confidence > 0.5, 'learned signature confidence meaningful'

/* Unknown-environment imported clip is inferred before observation classification. */
camera = .CameraModel~new('CAM-INFER', 640, 360)
do sampleIndex = 1 to 4
  supportValue = camera~environmentModel~observeSignature(.CameraConstant~ENV_DAY_DIRECT_SHADOW, .CameraEnvironmentSignature~new(0.49, 0.66, 0.55, 0.34, 0.13))
end
clip = .CameraImportedClip~new('auto-env', (15 * 3600) + (15 * 60), 2, .CameraConstant~ENV_UNKNOWN)
clip~environmentSignature = .CameraEnvironmentSignature~new(0.49, 0.67, 0.56, 0.34, 0.13)
frame = .CameraImportedFrame~new(clip~startSecond)
/* Under hard shadow this is photometric-only; diffuse daylight would retain it as mixed. */
frame~addObservation(.CameraObservation~new(frame~timestamp, .CameraBox~new('WALL', 400, 100, 150, 120), 0.35, 0.12))
clip~addFrame(frame)
summary = .CameraClipProcessor~process(camera, clip)
call assertEqual .CameraConstant~ENV_DAY_DIRECT_SHADOW, summary~environmentCode, 'clip summary stores inferred environment'
call assertEqual .CameraConstant~ENV_DAY_DIRECT_SHADOW, camera~environment~code, 'camera state stores inferred environment'
call assertEqual .CameraConstant~ENV_INFERENCE_PROFILE, camera~environment~inferenceMethod, 'camera reports learned inference method'
call assertEqual 1, summary~photometricCount, 'inferred shadow regime suppresses false mover'
call assertEqual 0, summary~trackCount, 'inferred shadow observation makes no track'

/* Measurement importer accepts an ENV signature line independently of CLIP environment code. */
measurementPath = 'camera_environment_inference_measurements.tmp'
call lineout measurementPath, 'CLIP|import-auto|' || ((4 * 3600) + (30 * 60)) || '|2|' || .CameraConstant~ENV_UNKNOWN
call lineout measurementPath, 'ENV|0.22|0.36|0.18|0.08|0.09'
call lineout measurementPath, 'FRAME|' || ((4 * 3600) + (30 * 60))
call stream measurementPath, 'c', 'close'
imported = .CameraMeasurementImporter~load(measurementPath)
call assertTrue imported~environmentSignature \== .nil, 'ENV signature imported'
importedInference = camera~environmentModel~infer(imported~environmentSignature, imported~startSecond)
call assertEqual .CameraConstant~ENV_NIGHT_ARTIFICIAL, importedInference~code, 'imported 04:30 signature inferred night'
call sysfiledelete measurementPath

/* Learned signature distributions survive persistence. */
persistPath = 'camera_environment_inference_model.tmp'
call assertEqual 1, .CameraModelPersistence~save(camera, persistPath), 'inference model saved'
restored = .CameraModelPersistence~load(persistPath)
call assertTrue restored \== .nil, 'inference model restored'
restoredInference = restored~environmentModel~infer(customSignature, (15 * 3600) + (15 * 60))
call assertEqual .CameraConstant~ENV_DAY_DIRECT_SHADOW, restoredInference~code, 'restored learned signature inferred'
call assertEqual .CameraConstant~ENV_INFERENCE_PROFILE, restoredInference~method, 'restored profile support retained'
call sysfiledelete persistPath

say '  prototype shadow confidence:' shadowInference~confidence
say '  learned shadow confidence:' customInference~confidence
say 'CAMERA ENVIRONMENT INFERENCE SMOKE: OK'
exit 0

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
