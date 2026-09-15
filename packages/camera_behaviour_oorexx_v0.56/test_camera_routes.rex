/* Route learning and description-length tests for CameraCore.cls */

say 'CAMERA ROUTE SMOKE START'

camera = .CameraModel~new('CAMROUTE', 640, 360)
road = .CameraBox~new('ROAD', 0, 100, 640, 200, camera~rootRegion)

/* First trajectory creates route R1 and is encoded literally. */
call feedTrack camera, road, 1000, 100, 150, 20, 0
call expireTracks camera, 1004
call assertEqual 'one route after first track', 1, camera~routeModel~routeCount
track1 = camera~tracks['T1']
call assertEqual 'first track route id', 'R1', track1~routeId
call assertEqual 'first track is route-new', .CameraConstant~ROUTE_NEW, track1~routeLearningState
firstBits = track1~descriptionBits
call assertTrue 'first encoding has positive cost', firstBits > 0

/* Same path with small offsets should match R1 and become much cheaper. */
call feedTrack camera, road, 1100, 104, 153, 20, 1
call expireTracks camera, 1104
call assertEqual 'still one route after matching track', 1, camera~routeModel~routeCount
track2 = camera~tracks['T2']
call assertEqual 'second track route id', 'R1', track2~routeId
call assertEqual 'second track known route', .CameraConstant~ROUTE_KNOWN, track2~routeLearningState
call assertTrue 'known route cheaper than literal', track2~descriptionBits < firstBits
call assertEqual 'R1 has two samples', 2, camera~routeModel~routes['R1']~sampleCount

/* Reverse trajectory is not the same route and must create R2. */
call feedTrack camera, road, 1200, 300, 150, -20, 0
call expireTracks camera, 1204
call assertEqual 'reverse path creates second route', 2, camera~routeModel~routeCount
track3 = camera~tracks['T3']
call assertEqual 'reverse track route id', 'R2', track3~routeId
call assertEqual 'reverse is route-new', .CameraConstant~ROUTE_NEW, track3~routeLearningState

/* A third near-R1 track should use the now better established prototype. */
call feedTrack camera, road, 1300, 98, 148, 21, 0
call expireTracks camera, 1304
track4 = camera~tracks['T4']
call assertEqual 'third forward path still R1', 'R1', track4~routeId
call assertEqual 'third forward path known', .CameraConstant~ROUTE_KNOWN, track4~routeLearningState
call assertEqual 'R1 now has three samples', 3, camera~routeModel~routes['R1']~sampleCount

say 'CAMERA ROUTE SMOKE: OK'
exit 0

feedTrack: procedure
  use arg cameraObject, parentRegion, startSecond, startX, startY, deltaX, deltaY
  do step = 0 to 2
    observations = .array~new
    x = startX + (deltaX * step)
    y = startY + (deltaY * step)
    boxId = 'B' || startSecond || '_' || step
    movingBox = .CameraBox~new(boxId, x, y, 24, 40, parentRegion)
    observations~append(.CameraObservation~new(startSecond + step, movingBox, 0.04, 0.50))
    cameraObject~observeFrame(startSecond + step, observations)
  end
  return

expireTracks: procedure
  use arg cameraObject, firstEmptySecond
  emptyObservations = .array~new
  cameraObject~observeFrame(firstEmptySecond, emptyObservations)
  cameraObject~observeFrame(firstEmptySecond + 1, emptyObservations)
  cameraObject~observeFrame(firstEmptySecond + 2, emptyObservations)
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
  say '  actual:' actual
  exit 1

::requires 'CameraCore.cls'
