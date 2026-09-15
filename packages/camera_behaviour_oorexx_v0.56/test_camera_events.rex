/* Event grammar tests for CameraCore.cls */

say 'CAMERA EVENT SMOKE START'

camera = .CameraModel~new('CAMEVENT', 640, 360)
scene = camera~rootRegion

/* Track A moves toward B, pauses, reverses, then departs. */
call feedObservation camera, scene, 100, 'A1', 100, 150, 20, 40
call feedObservation camera, scene, 101, 'A2', 130, 150, 20, 40
call feedObservation camera, scene, 102, 'A3', 160, 150, 20, 40
call feedObservation camera, scene, 103, 'A4', 160, 150, 20, 40
call feedObservation camera, scene, 104, 'A5', 130, 150, 20, 40
call expireTracks camera, 105

trackA = camera~tracks['T1']
call assertEqual 'A ended', .CameraConstant~TRACK_ENDED, trackA~state
call assertEqual 'A enter event', 1, camera~eventGrammar~countType(.CameraConstant~EVENT_ENTER)
call assertEqual 'A stop event', 1, camera~eventGrammar~countType(.CameraConstant~EVENT_STOP)
call assertEqual 'A reverse event', 1, camera~eventGrammar~countType(.CameraConstant~EVENT_REVERSE)
call assertEqual 'A exit event', 1, camera~eventGrammar~countType(.CameraConstant~EVENT_EXIT)
call assertTrue 'A move events exist', camera~eventGrammar~countType(.CameraConstant~EVENT_MOVE) >= 3

/* Fresh camera: two simultaneous tracks converge, become close, then separate. */
pairCamera = .CameraModel~new('CAMPAIR', 640, 360)
pairScene = pairCamera~rootRegion
call feedPair pairCamera, pairScene, 200, 100, 300
call feedPair pairCamera, pairScene, 201, 140, 260
call feedPair pairCamera, pairScene, 202, 180, 220
call feedPair pairCamera, pairScene, 203, 140, 260
call feedPair pairCamera, pairScene, 204, 100, 300
call expireTracks pairCamera, 205

call assertEqual 'pair has approach', 1, pairCamera~eventGrammar~countType(.CameraConstant~EVENT_APPROACH)
call assertEqual 'pair has close', 1, pairCamera~eventGrammar~countType(.CameraConstant~EVENT_CLOSE)
call assertEqual 'pair has separate', 1, pairCamera~eventGrammar~countType(.CameraConstant~EVENT_SEPARATE)

/* Photometric-only wall change must not generate movement grammar. */
photoCamera = .CameraModel~new('CAMPHOTO', 640, 360)
obs = .array~new
wall = .CameraBox~new('WALL', 400, 80, 200, 240, photoCamera~rootRegion)
obs~append(.CameraObservation~new(300, wall, 0.70, 0.02))
frameOutcome = photoCamera~observeFrame(300, obs)
call assertEqual 'photometric counted', 1, frameOutcome~photometricCount
call assertEqual 'photometric no tracks', 0, photoCamera~activeTrackCount
call assertEqual 'photometric no grammar events', 0, photoCamera~eventGrammar~eventCount

say 'CAMERA EVENT SMOKE: OK'
exit 0

feedObservation: procedure
  use arg cameraObject, parentRegion, secondOfDay, boxId, x, y, width, height
  observations = .array~new
  box = .CameraBox~new(boxId, x, y, width, height, parentRegion)
  observations~append(.CameraObservation~new(secondOfDay, box, 0.04, 0.50))
  cameraObject~observeFrame(secondOfDay, observations)
  return

feedPair: procedure
  use arg cameraObject, parentRegion, secondOfDay, xA, xB
  observations = .array~new
  observations~append(.CameraObservation~new(secondOfDay, .CameraBox~new('PA' || secondOfDay, xA, 150, 20, 40, parentRegion), 0.04, 0.50))
  observations~append(.CameraObservation~new(secondOfDay, .CameraBox~new('PB' || secondOfDay, xB, 150, 20, 40, parentRegion), 0.04, 0.50))
  cameraObject~observeFrame(secondOfDay, observations)
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
