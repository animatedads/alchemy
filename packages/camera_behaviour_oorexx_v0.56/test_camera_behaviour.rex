/* Time-conditioned behaviour model tests for CameraCore.cls */

say 'CAMERA BEHAVIOUR SMOKE START'

model = .CameraBehaviourModel~new
w0015 = .CameraBehaviourWindow~new(15 * 60, 30 * 60)
w0430 = .CameraBehaviourWindow~new((4 * 3600) + (30 * 60), 30 * 60)
model~addWindow(w0015)
model~addWindow(w0430)

/* Train different event grammars into separate time neighbourhoods. */
do sampleIndex = 1 to 20
  model~observeEvent(15 * 60, .CameraConstant~EVENT_APPROACH)
  model~observeEvent((4 * 3600) + (30 * 60), .CameraConstant~EVENT_MOVE)
end

approachAt0015 = model~eventDescriptionBits(15 * 60, .CameraConstant~EVENT_APPROACH)
approachAt0430 = model~eventDescriptionBits((4 * 3600) + (30 * 60), .CameraConstant~EVENT_APPROACH)
call assertTrue 'approach cheaper at trained 00:15 time', approachAt0015 < approachAt0430

moveAt0430 = model~eventDescriptionBits((4 * 3600) + (30 * 60), .CameraConstant~EVENT_MOVE)
moveAt0015 = model~eventDescriptionBits(15 * 60, .CameraConstant~EVENT_MOVE)
call assertTrue 'move cheaper at trained 04:30 time', moveAt0430 < moveAt0015

/* A whole interaction grammar can be priced as an auditable sequence. */
interaction = .array~of(.CameraConstant~EVENT_APPROACH, .CameraConstant~EVENT_CLOSE, .CameraConstant~EVENT_SEPARATE)
do sampleIndex = 1 to 20
  model~observeEvent(15 * 60, .CameraConstant~EVENT_CLOSE)
  model~observeEvent(15 * 60, .CameraConstant~EVENT_SEPARATE)
end
interactionAt0015 = model~eventSequenceDescriptionBits(15 * 60, interaction)
interactionAt0430 = model~eventSequenceDescriptionBits((4 * 3600) + (30 * 60), interaction)
call assertTrue 'interaction grammar cheaper at trained 00:15 time', interactionAt0015 < interactionAt0430

/* The same principle applies to known routes. */
do sampleIndex = 1 to 20
  model~observeRoute(15 * 60, 'R7')
  model~observeRoute((4 * 3600) + (30 * 60), 'R2')
end

r7At0015 = model~routeDescriptionBits(15 * 60, 'R7', 2)
r7At0430 = model~routeDescriptionBits((4 * 3600) + (30 * 60), 'R7', 2)
call assertTrue 'R7 cheaper at 00:15', r7At0015 < r7At0430

/* Overlapping windows retain weighted contribution rather than hard buckets. */
overlapModel = .CameraBehaviourModel~new
overlap0000 = .CameraBehaviourWindow~new(0, 3600)
overlap0015 = .CameraBehaviourWindow~new(15 * 60, 3600)
overlap0030 = .CameraBehaviourWindow~new(30 * 60, 3600)
overlapModel~addWindow(overlap0000)
overlapModel~addWindow(overlap0015)
overlapModel~addWindow(overlap0030)
overlapModel~observeEvent(15 * 60, .CameraConstant~EVENT_CLOSE)
call assertNear '00:15 event full weight', 1, overlap0015~eventWeight(.CameraConstant~EVENT_CLOSE), 0.0001
call assertNear '00:00 event overlap', 0.75, overlap0000~eventWeight(.CameraConstant~EVENT_CLOSE), 0.0001
call assertNear '00:30 event overlap', 0.75, overlap0030~eventWeight(.CameraConstant~EVENT_CLOSE), 0.0001

/* Regular windows provide a ready camera time surface. */
regularModel = .CameraBehaviourModel~new
added = regularModel~installRegularWindows(15 * 60, 60 * 60)
call assertEqual '96 quarter-hour centres', 96, added
call assertEqual '96 windows installed', 96, regularModel~windows~items

/* Camera integration: ended tracks learn route/event temporal costs before updating baseline. */
camera = .CameraModel~new('CAMTIME', 640, 360)
camera~behaviour~addWindow(.CameraBehaviourWindow~new(15 * 60, 60 * 60))
scene = camera~rootRegion
call feedObservation camera, scene, 900, 'B1', 100, 150, 20, 40
call feedObservation camera, scene, 901, 'B2', 130, 150, 20, 40
call feedObservation camera, scene, 902, 'B3', 160, 150, 20, 40
call expireTracks camera, 903

track = camera~tracks['T1']
call assertTrue 'track has route', track~routeId <> ''
call assertTrue 'track has temporal route cost', track~temporalRouteBits > 0
call assertTrue 'events derived', camera~eventGrammar~eventCount > 0

do derivedEvent over camera~eventGrammar~events
  call assertTrue 'event has temporal description cost', derivedEvent~descriptionBits > 0
end

/* Check the explicit information measure rather than relying on host math libraries. */
call assertNear 'log2(2)', 1, .CameraMath~log2(2), 0.0001
call assertNear 'surprise p=.5', 1, .CameraMath~surpriseBits(0.5), 0.0001

say 'CAMERA BEHAVIOUR SMOKE: OK'
exit 0

feedObservation: procedure
  use arg cameraObject, parentRegion, secondOfDay, boxId, x, y, width, height
  observations = .array~new
  box = .CameraBox~new(boxId, x, y, width, height, parentRegion)
  observations~append(.CameraObservation~new(secondOfDay, box, 0.04, 0.50))
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

assertNear: procedure
  use arg label, expected, actual, tolerance
  if abs(expected - actual) <= tolerance then return .true
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
