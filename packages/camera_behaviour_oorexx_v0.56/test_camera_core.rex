/* Runtime smoke tests for CameraCore.cls */

say 'CAMERA CORE SMOKE START'

root = .CameraBox~new('ROOT', 0, 0, 640, 360)
road = .CameraBox~new('ROAD', 100, 100, 400, 180, root)
call assertEqual 'nested child count', 1, root~children~items
call assertEqual 'road parent identity', .true, road~parent == root
call assertEqual 'contains point', .true, road~containsPoint(200, 150)
call assertEqual 'outside point', .false, road~containsPoint(20, 20)

wall = .CameraBox~new('WALL', 400, 80, 200, 260, root)
lightObs = .CameraObservation~new(100, wall, 0.55, 0.03)
call assertEqual 'brake light is photometric', .CameraConstant~CHANGE_PHOTOMETRIC, lightObs~changeType
call assertEqual 'photometric is not mover', .false, lightObs~isMoverCandidate

personBox1 = .CameraBox~new('P1A', 240, 180, 20, 54, road)
moveObs1 = .CameraObservation~new(101, personBox1, 0.08, 0.46)
call assertEqual 'structural change type', .CameraConstant~CHANGE_STRUCTURAL, moveObs1~changeType
call assertEqual 'structural is mover', .true, moveObs1~isMoverCandidate

track = .CameraTrack~new('T1')
track~addObservation(moveObs1)
personBox2 = .CameraBox~new('P1B', 252, 186, 20, 54, road)
moveObs2 = .CameraObservation~new(102, personBox2, 0.07, 0.44)
track~addObservation(moveObs2)
call assertEqual 'track point count', 2, track~pointCount
call assertEqual 'track dx', 12, track~displacementX
call assertEqual 'track dy', 6, track~displacementY

/* 00:15 expressed as seconds after midnight. */
t0015 = 15 * 60
model = .CameraBehaviourModel~new
w0000 = .CameraBehaviourWindow~new(0, 3600)
w0015 = .CameraBehaviourWindow~new(15 * 60, 3600)
w0030 = .CameraBehaviourWindow~new(30 * 60, 3600)
w0430 = .CameraBehaviourWindow~new((4 * 3600) + (30 * 60), 3600)
model~addWindow(w0000)
model~addWindow(w0015)
model~addWindow(w0030)
model~addWindow(w0430)
weight = model~observe(t0015)
call assertNear '00:15 own window weight', 1, w0015~weightedObservations, 0.0001
call assertNear '00:00 overlap weight', 0.75, w0000~weightedObservations, 0.0001
call assertNear '00:30 overlap weight', 0.75, w0030~weightedObservations, 0.0001
call assertNear '04:30 no overlap', 0, w0430~weightedObservations, 0.0001
call assertNear 'total overlap weight', 2.5, weight, 0.0001

camera = .CameraModel~new('CAM01', 640, 360)
r = camera~observe(lightObs)
call assertEqual 'camera suppresses light mover', .CameraConstant~CHANGE_PHOTOMETRIC, r
r = camera~observe(moveObs1)
call assertEqual 'camera creates track object', .true, r~isA(.CameraTrack)
call assertEqual 'camera track has one point', 1, r~pointCount

say 'CAMERA CORE SMOKE: OK'
exit 0

assertEqual: procedure
  use arg label, expected, actual
  if expected == actual then return .true
  say 'ASSERT FAILED:' label
  say '  expected:' expected
  say '  actual:  ' actual
  exit 1

assertNear: procedure
  use arg label, expected, actual, tolerance
  difference = abs(expected - actual)
  if difference <= tolerance then return .true
  say 'ASSERT FAILED:' label
  say '  expected:' expected
  say '  actual:  ' actual
  say '  difference:' difference
  exit 1

::requires 'CameraCore.cls'
