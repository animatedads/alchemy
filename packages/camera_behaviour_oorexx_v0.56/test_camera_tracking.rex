/* Runtime tracking tests for CameraCore.cls */

say 'CAMERA TRACKING SMOKE START'

camera = .CameraModel~new('CAM01', 640, 360)
root = camera~rootRegion
road = .CameraBox~new('ROAD', 0, 100, 640, 200, root)

/* Frame 1: two independent movers. */
obs = .array~new
obs~append(.CameraObservation~new(100, .CameraBox~new('A1', 100, 160, 20, 50, road), 0.05, 0.45))
obs~append(.CameraObservation~new(100, .CameraBox~new('B1', 400, 165, 65, 35, road), 0.06, 0.50))
r = camera~observeFrame(100, obs)
call assertEqual 'frame1 mover count', 2, r~moverCount
call assertEqual 'frame1 creates two tracks', 2, r~newTrackCount
call assertEqual 'frame1 active tracks', 2, camera~activeTrackCount
trackA = r~assignments[1]
trackB = r~assignments[2]
call assertEqual 'frame1 distinct track ids', .true, trackA~id \= trackB~id

/* Frame 2: both move. They must associate with their previous tracks. */
obs = .array~new
obs~append(.CameraObservation~new(101, .CameraBox~new('A2', 112, 164, 20, 50, road), 0.05, 0.47))
obs~append(.CameraObservation~new(101, .CameraBox~new('B2', 388, 165, 65, 35, road), 0.05, 0.48))
r = camera~observeFrame(101, obs)
call assertEqual 'frame2 matched count', 2, r~matchedCount
call assertEqual 'frame2 no new tracks', 0, r~newTrackCount
call assertEqual 'A remains same identity', trackA~id, r~assignments[1]~id
call assertEqual 'B remains same identity', trackB~id, r~assignments[2]~id
call assertEqual 'A point count', 2, trackA~pointCount
call assertEqual 'B point count', 2, trackB~pointCount
call assertNear 'A velocity x', 12, trackA~velocityX, 0.001
call assertNear 'B velocity x', -12, trackB~velocityX, 0.001

/* Frame 3: A is temporarily hidden, B continues, and a wall light changes. */
obs = .array~new
obs~append(.CameraObservation~new(102, .CameraBox~new('B3', 376, 165, 65, 35, road), 0.05, 0.48))
obs~append(.CameraObservation~new(102, .CameraBox~new('W1', 500, 100, 120, 180, root), 0.55, 0.03))
r = camera~observeFrame(102, obs)
call assertEqual 'photometric event counted', 1, r~photometricCount
call assertEqual 'only B matched', 1, r~matchedCount
call assertEqual 'A enters occluded state', .CameraConstant~TRACK_OCCLUDED, trackA~state
call assertEqual 'A missed one frame', 1, trackA~missedFrames
call assertEqual 'B still active', .CameraConstant~TRACK_ACTIVE, trackB~state

/* Frame 4: A reappears near its predicted position and should recover identity. */
obs = .array~new
obs~append(.CameraObservation~new(103, .CameraBox~new('A4', 136, 172, 20, 50, road), 0.04, 0.44))
obs~append(.CameraObservation~new(103, .CameraBox~new('B4', 364, 165, 65, 35, road), 0.05, 0.49))
r = camera~observeFrame(103, obs)
call assertEqual 'frame4 both matched', 2, r~matchedCount
call assertEqual 'A recovered same identity', trackA~id, r~assignments[1]~id
call assertEqual 'A active after recovery', .CameraConstant~TRACK_ACTIVE, trackA~state
call assertEqual 'A missed reset', 0, trackA~missedFrames
call assertEqual 'A point count after occlusion', 3, trackA~pointCount

/* A separate camera tests expiry after three missed frames (default max = 2). */
expiry = .CameraModel~new('CAM02', 640, 360)
obs = .array~new
obs~append(.CameraObservation~new(200, .CameraBox~new('X1', 50, 50, 20, 20), 0.05, 0.40))
r = expiry~observeFrame(200, obs)
trackX = r~assignments[1]
empty = .array~new
expiry~observeFrame(201, empty)
call assertEqual 'expiry miss 1 occluded', .CameraConstant~TRACK_OCCLUDED, trackX~state
expiry~observeFrame(202, empty)
call assertEqual 'expiry miss 2 occluded', .CameraConstant~TRACK_OCCLUDED, trackX~state
expiry~observeFrame(203, empty)
call assertEqual 'expiry miss 3 ended', .CameraConstant~TRACK_ENDED, trackX~state
call assertEqual 'expired not active', 0, expiry~activeTrackCount

/* Midnight wrap: 23:59:59 to 00:00:01 is two seconds, not a day-old gap. */
midnight = .CameraTrack~new('MID')
midnight~addObservation(.CameraObservation~new(86399, .CameraBox~new('M1', 10, 10, 10, 10), 0.05, 0.4))
midnight~addObservation(.CameraObservation~new(1, .CameraBox~new('M2', 14, 10, 10, 10), 0.05, 0.4))
call assertNear 'midnight velocity', 2, midnight~velocityX, 0.001

say 'CAMERA TRACKING SMOKE: OK'
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
