/* Complete learned-world generation freeze tests. */

say 'CAMERA LEARNED WORLD GENERATION SMOKE START'

camera = .CameraModel~new('CAMWORLD', 640, 360)
root = camera~rootRegion
road = .CameraBox~new('ROAD', 100, 100, 400, 120, root)
lane = .CameraBox~new('LANE', 100, 130, 400, 60, road)

/* Learn one spatial primitive, one route, and one transition before G1. */
t1 = buildTrack('T1', 1000, 140, 140, 10, 2, 30, 20)
p1 = camera~learnSpatialPrimitive(t1)
ignoredRoute = camera~routeModel~learnTrack(t1)
x1 = camera~transitionModel~learn('M1', 'M2')

g1 = camera~publishGeneration(1100)
call assertEqual 'g1 version', '6', g1~version
call assertEqual 'g1 region count', 3, g1~regionCount
call assertEqual 'g1 primitive count', 1, g1~primitiveCount
call assertEqual 'g1 route count', 1, g1~routeCount
call assertEqual 'g1 transition count', 1, g1~transitionCount
call assertTrue 'g1 has lane', g1~sceneGeometry~region('ROOT/ROAD/LANE') \== .nil
call assertTrue 'g1 has route R1', g1~route('R1') \== .nil
call assertTrue 'g1 has transition X1', g1~transition('X1') \== .nil

g1SemanticBefore = g1~semanticCanonicalText

/* Mutate every live learned surface after G1. */
kerb = .CameraBox~new('KERB', 100, 190, 400, 30, road)
t2 = buildTrack('T2', 2000, 430, 140, -20, 1, 30, 20)
ignoredPrimitive = camera~learnSpatialPrimitive(t2)
ignoredRoute2 = camera~routeModel~learnTrack(t2)
x2 = camera~transitionModel~learn('M2', 'M3')

/* Also mutate an existing live route and transition to prove deep freezing. */
liveR1 = camera~routeModel~routes['R1']
liveR1~sampleCount = liveR1~sampleCount + 100
liveX1 = camera~transitionModel~transitionForId('X1')
liveX1~sampleCount = liveX1~sampleCount + 100

call assertEqual 'g1 region still frozen', 3, g1~regionCount
call assertEqual 'g1 primitive still frozen', 1, g1~primitiveCount
call assertEqual 'g1 route still frozen', 1, g1~routeCount
call assertEqual 'g1 transition still frozen', 1, g1~transitionCount
call assertTrue 'g1 does not know kerb', g1~sceneGeometry~region('ROOT/ROAD/KERB') == .nil
call assertEqual 'g1 R1 sample count frozen', 1, g1~route('R1')~sampleCount
call assertEqual 'g1 X1 sample count frozen', 1, g1~transition('X1')~sampleCount
call assertEqual 'g1 semantic identity unchanged', g1SemanticBefore, g1~semanticCanonicalText

/* Publish G2: the new generation sees the newer world. */
g2 = camera~publishGeneration(2100)
call assertEqual 'g2 region count', 4, g2~regionCount
call assertTrue 'g2 knows kerb', g2~sceneGeometry~region('ROOT/ROAD/KERB') \== .nil
call assertTrue 'g2 has at least two primitives', g2~primitiveCount >= 2
call assertTrue 'g2 has at least two routes', g2~routeCount >= 2
call assertEqual 'g2 two transitions', 2, g2~transitionCount
call assertEqual 'g1 superseded lifecycle state', .CameraConstant~GENERATION_SUPERSEDED, g1~state
call assertEqual 'superseding does not alter g1 semantic identity', g1SemanticBefore, g1~semanticCanonicalText

/* Collection access is defensive. */
routesCopy = g1~routes
routesCopy~empty
call assertEqual 'g1 routes remain frozen after caller mutation', 1, g1~routeCount
transitionsCopy = g1~transitions
transitionsCopy~empty
call assertEqual 'g1 transitions remain frozen after caller mutation', 1, g1~transitionCount

say '  G1 regions/routes/transitions:' g1~regionCount g1~routeCount g1~transitionCount
say '  G2 regions/routes/transitions:' g2~regionCount g2~routeCount g2~transitionCount
say 'CAMERA LEARNED WORLD GENERATION SMOKE: OK'
exit 0

buildTrack: procedure
  use arg id, startTimestamp, startX, startY, stepX, stepY, width, height
  track = .CameraTrack~new(id)
  do pointIndex = 0 to 4
    call addPoint track, startTimestamp + pointIndex, startX + (stepX * pointIndex), startY + (stepY * pointIndex), width, height
  end
  return track

addPoint: procedure
  use arg track, timestamp, x, y, width, height
  observation = .CameraObservation~new(timestamp, .CameraBox~new('OBS', x, y, width, height), 1, 1)
  ignoredCount = track~addObservation(observation)
  return

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
