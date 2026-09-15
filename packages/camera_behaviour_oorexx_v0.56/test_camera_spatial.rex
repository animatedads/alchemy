/* Spatial zones, route tubes, and zone-conditioned behaviour tests. */

say 'CAMERA SPATIAL SMOKE START'

camera = .CameraModel~new('CAMSPACE', 640, 360)
road = .CameraBox~new('ROAD', 0, 80, 640, 220, camera~rootRegion)

/* Establish a straight route with five observations. */
call feedPath camera, road, 1000, 100, 150, 20, 0, 5, -1, 0
call expireTracks camera, 1006
track1 = camera~tracks['T1']
call assertEqual 'first route is R1', 'R1', track1~routeId
call assertTrue 'entry zone learned', track1~entryZoneId <> ''
call assertTrue 'exit zone learned', track1~exitZoneId <> ''
call assertTrue 'at least two endpoint zones learned', camera~spatialModel~zones~zoneCount >= 2

/* A near-identical path should fit the learned route tube. */
call feedPath camera, road, 1100, 102, 152, 20, 0, 5, -1, 0
call expireTracks camera, 1106
track2 = camera~tracks['T2']
call assertEqual 'second path reuses R1', 'R1', track2~routeId
call assertTrue 'normal route tube residual small', track2~routeTubeResidual < 15

/* Same entry/mid/exit geometry, but a large intermediate excursion. */
call feedPath camera, road, 1200, 100, 150, 20, 0, 5, 1, -70
call expireTracks camera, 1206
track3 = camera~tracks['T3']
call assertEqual 'detour still matches route prototype', 'R1', track3~routeId
call assertTrue 'detour has large route tube residual', track3~routeTubeResidual > camera~eventGrammar~routeDeviationThreshold
call assertTrue 'deviation event emitted', camera~eventGrammar~countType(.CameraConstant~EVENT_DEVIATE) >= 1

deviationFound = .false
do spatialEvent over camera~eventGrammar~events
  if spatialEvent~eventType = .CameraConstant~EVENT_DEVIATE then do
    deviationFound = .true
    call assertEqual 'deviation carries route id', 'R1', spatialEvent~routeId
    call assertEqual 'deviation timestamp is maximum excursion', 1201, spatialEvent~timestamp
    call assertTrue 'deviation assigned a zone', spatialEvent~zoneId <> ''
    call assertTrue 'zone-conditioned bits recorded', spatialEvent~zoneDescriptionBits > 0
  end
end
call assertTrue 'deviation event inspected', deviationFound

/* Zone/event combinations are learned in overlapping time windows. */
model = .CameraBehaviourModel~new
model~addWindow(.CameraBehaviourWindow~new(15 * 60, 30 * 60))
model~addWindow(.CameraBehaviourWindow~new((4 * 3600) + (30 * 60), 30 * 60))
do sampleIndex = 1 to 20
  model~observeZoneEvent(15 * 60, 'Z99', .CameraConstant~EVENT_STOP)
end
stopAt0015 = model~zoneEventDescriptionBits(15 * 60, 'Z99', .CameraConstant~EVENT_STOP)
stopAt0430 = model~zoneEventDescriptionBits((4 * 3600) + (30 * 60), 'Z99', .CameraConstant~EVENT_STOP)
call assertTrue 'STOP at learned zone cheaper at 00:15', stopAt0015 < stopAt0430

say 'CAMERA SPATIAL SMOKE: OK'
exit 0

feedPath: procedure
  use arg cameraObject, parentRegion, startSecond, startX, startY, deltaX, deltaY, pointCount, detourIndex, detourY
  do step = 0 to pointCount - 1
    observations = .array~new
    x = startX + (deltaX * step)
    y = startY + (deltaY * step)
    if step = detourIndex then y = y + detourY
    boxId = 'S' || startSecond || '_' || step
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
