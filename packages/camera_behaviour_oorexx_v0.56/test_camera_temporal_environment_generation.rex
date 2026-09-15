/* Temporal/environmental learned-world generation freeze tests. */

say 'CAMERA TEMPORAL ENVIRONMENT GENERATION SMOKE START'

camera = .CameraModel~new('CAMTIMEENV', 640, 360)

/* Establish two overlapping time windows and feed baseline evidence. */
camera~behaviour~addWindow(.CameraBehaviourWindow~new(43200, 3600))
camera~behaviour~addWindow(.CameraBehaviourWindow~new(44100, 3600))
ignored = camera~behaviour~observeRoute(43200, 'R1')
ignored = camera~behaviour~observeEvent(43200, .CameraConstant~EVENT_MOVE)
ignored = camera~behaviour~observeMetric(43200, 'TRACK_RATE', 12)
ignored = camera~behaviour~observeMetric(43500, 'TRACK_RATE', 14)

/* Establish a learned daylight environment profile. */
profile = camera~environmentModel~profileFor(.CameraConstant~ENV_DAY_DIFFUSE)
obs1 = .CameraObservation~new(43200, .CameraBox~new('B1', 0, 0, 20, 20), 0.04, 0.03)
obs2 = .CameraObservation~new(43201, .CameraBox~new('B2', 0, 0, 20, 20), 0.05, 0.04)
obs3 = .CameraObservation~new(43202, .CameraBox~new('B3', 0, 0, 20, 20), 0.06, 0.05)
ignored = profile~observeBackgroundObservation(obs1)
ignored = profile~observeBackgroundObservation(obs2)
ignored = profile~observeBackgroundObservation(obs3)
ignored = profile~observeMetric('PHOTOMETRIC_RATE', 0.15)
sig = .CameraEnvironmentSignature~new(0.65, 0.25, 0.15, 0.25, 0.06)
ignored = profile~observeSignature(sig)
ignored = profile~observeSignature(sig)
ignored = profile~observeSignature(sig)

g1 = camera~publishGeneration(44000)
call assertEqual 'generation v6', '6', g1~version
call assertEqual 'two behaviour windows frozen', 2, g1~behaviourWindowCount
call assertEqual 'one environment profile frozen', 1, g1~environmentProfileCount

w1 = g1~behaviourModel~windowAtCentre(43200)
call assertTrue '43200 window present', w1 \== .nil
call assertTrue 'route weight present', w1~routeWeightTotal > 0
trackRate1 = w1~metric('TRACK_RATE')
call assertTrue 'track rate distribution frozen', trackRate1 \== .nil
call assertTrue 'track rate has support', trackRate1~sampleCount >= 1

env1 = g1~environmentModel~profile(.CameraConstant~ENV_DAY_DIFFUSE)
call assertTrue 'day diffuse profile present', env1 \== .nil
call assertEqual 'background luma support frozen', 3, env1~backgroundLuma~sampleCount
call assertEqual 'signature support frozen', 3, env1~signatureMetric('GLOBAL_LUMA')~sampleCount
call assertTrue 'environment thresholds materialized', env1~structuralThreshold > 0

g1Canonical = g1~semanticCanonicalText
g1RouteWeight = w1~routeWeightTotal
g1TrackSamples = trackRate1~sampleCount
g1LumaSamples = env1~backgroundLuma~sampleCount

/* Mutate both live models after publication. */
ignored = camera~behaviour~observeRoute(43200, 'R1')
ignored = camera~behaviour~observeRoute(43200, 'R2')
ignored = camera~behaviour~observeMetric(43200, 'TRACK_RATE', 100)
camera~behaviour~addWindow(.CameraBehaviourWindow~new(45000, 1800))
obs4 = .CameraObservation~new(43203, .CameraBox~new('B4', 0, 0, 20, 20), 0.40, 0.20)
ignored = profile~observeBackgroundObservation(obs4)
ignored = profile~observeMetric('PHOTOMETRIC_RATE', 0.90)
nightProfile = camera~environmentModel~profileFor(.CameraConstant~ENV_NIGHT_ARTIFICIAL)
ignored = nightProfile~observeMetric('PHOTOMETRIC_RATE', 0.30)

call assertEqual 'g1 window count unchanged', 2, g1~behaviourWindowCount
call assertEqual 'g1 profile count unchanged', 1, g1~environmentProfileCount
call assertEqual 'g1 route total unchanged', g1RouteWeight, w1~routeWeightTotal
call assertEqual 'g1 metric support unchanged', g1TrackSamples, trackRate1~sampleCount
call assertEqual 'g1 luma support unchanged', g1LumaSamples, env1~backgroundLuma~sampleCount
call assertTrue 'g1 has no night profile', g1~environmentModel~profile(.CameraConstant~ENV_NIGHT_ARTIFICIAL) == .nil
call assertEqual 'g1 semantic identity stable', g1Canonical, g1~semanticCanonicalText

/* G2 observes the newer temporal/environmental world. */
g2 = camera~publishGeneration(46000)
call assertEqual 'g2 sees third window', 3, g2~behaviourWindowCount
call assertEqual 'g2 sees second profile', 2, g2~environmentProfileCount
w2 = g2~behaviourModel~windowAtCentre(43200)
call assertTrue 'g2 route total advanced', w2~routeWeightTotal > g1RouteWeight
call assertTrue 'g2 metric support advanced', w2~metric('TRACK_RATE')~sampleCount > g1TrackSamples
env2 = g2~environmentModel~profile(.CameraConstant~ENV_DAY_DIFFUSE)
call assertTrue 'g2 luma support advanced', env2~backgroundLuma~sampleCount > g1LumaSamples
call assertTrue 'g2 has night profile', g2~environmentModel~profile(.CameraConstant~ENV_NIGHT_ARTIFICIAL) \== .nil

say '  G1 windows/profiles:' g1~behaviourWindowCount g1~environmentProfileCount
say '  G2 windows/profiles:' g2~behaviourWindowCount g2~environmentProfileCount
say 'CAMERA TEMPORAL ENVIRONMENT GENERATION SMOKE: OK'
exit 0

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
