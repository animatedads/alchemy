/* Alchemy base-class migration tests for Camera Behaviour v0.37. */

say 'CAMERA ALCHEMY BASE SMOKE START'

camera = .CameraModel~new('CAM-ALCHEMY', 640, 360)
call assertTrue 'camera derives from AlchemyObject', camera~isA(.AlchemyObject)
call assertTrue 'camera has stable alchemy object id', camera~alchemyObjectId~length > 0
call assertTrue 'camera Alchemy surface contract', camera~checkSurfaceContract~ok

/* Build enough learned state to publish a real generation. */
camera~behaviour~addWindow(.CameraBehaviourWindow~new(43200, 3600))
do sample = 1 to 5
  second = 43100 + sample
  ignoredMetric = camera~behaviour~observeMetric(second, 'TRACK_RATE', 10 + sample)
end

g1 = camera~publishGeneration(44000)
call assertTrue 'generation derives from AlchemyObject', g1~isA(.AlchemyObject)
call assertTrue 'generation Alchemy surface contract', g1~checkSurfaceContract~ok
call assertEqual 'generation id', 'G1', g1~id

/* Camera records a detached relationship to the generation. */
relationships = camera~relationshipEvidence('PUBLIC')
/* CUSTOMER relationship is intentionally absent from PUBLIC evidence. */
call assertEqual 'public relationship evidence remains bounded', 0, relationships~items

/* Instrumentation remains observable without becoming Camera business state. */
events = camera~instrumentationEvents
call assertTrue 'publish instrumentation recorded', events~items >= 1
call assertEqual 'publish point', 'CAMERA.GENERATION.PUBLISH', events[events~items]['point']

genEvents = g1~instrumentationEvents
call assertEqual 'generation initially has no match events', 0, genEvents~items

/* Pinned assessment creates Alchemy-derived explanatory evidence. */
summary = .CameraClipSummary~new('CLIP-ALG', 43100, 200)
summary~dayClass = .CameraConstant~DAY_UNKNOWN
summary~environmentCode = .CameraConstant~ENV_DAY_DIFFUSE
do n = 1 to 40
  ignoredTrack = summary~addTrack(.CameraTrack~new('T' || n))
end
assessment = camera~assessSummaryAtGeneration(summary, 'G1', 3, 2.5)
call assertTrue 'assessment exists', assessment \== .nil
call assertTrue 'assessment evidence derives from AlchemyObject', assessment~evidence~isA(.AlchemyObject)
call assertTrue 'assessment evidence surface contract', assessment~evidence~checkSurfaceContract~ok
call assertEqual 'assessment evidence generation', 'G1', assessment~evidence~generationId
call assertTrue 'metric evidence instrumentation recorded', assessment~evidence~instrumentationEvents~items > 0

cameraEvents = camera~instrumentationEvents
call assertTrue 'pinned assessment instrumentation recorded', cameraEvents~items >= 2
call assertEqual 'assessment point', 'CAMERA.ASSESSMENT.PINNED', cameraEvents[cameraEvents~items]['point']

/* Matching against generation uses inherited instrumentation but does not change semantic content. */
track = .CameraTrack~new('TMATCH')
do n = 0 to 4
  observation = .CameraObservation~new(45000+n, .CameraBox~new('B'||n, 100+(n*5), 100, 20, 20), 1, 1)
  ignoredPoint = track~addObservation(observation)
end
ignoredLearn = camera~learnSpatialPrimitive(track)
g2 = camera~publishGeneration(45010)
matchResult = camera~matchSpatialPrimitive(track, 'G2')
call assertTrue 'generation match result exists', matchResult \== .nil
call assertTrue 'generation match instrumentation recorded', g2~instrumentationEvents~items > 0

/* Alchemy lifecycle is independent of Camera semantic generation lifecycle. */
g1Before = g1~semanticCanonicalText
call assertEqual 'g1 superseded by g2', .CameraConstant~GENERATION_SUPERSEDED, g1~state
call assertEqual 'semantic generation remains unchanged by supersede', g1Before, g1~semanticCanonicalText

say '  camera object:' camera~alchemyObjectId
say '  generation object:' g1~alchemyObjectId
say '  evidence object:' assessment~evidence~alchemyObjectId
say 'CAMERA ALCHEMY BASE SMOKE: OK'
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
