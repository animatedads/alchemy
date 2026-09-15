/* Nested spatial relation and relative track encoding tests for CameraCore.cls */

say 'CAMERA SPATIAL RELATION SMOKE START'

root = .CameraBox~new('ROOT', 0, 0, 640, 360)
road = .CameraBox~new('ROAD', 100, 100, 400, 120, root)
lane = .CameraBox~new('LANE', 100, 130, 400, 60, road)
kerb = .CameraBox~new('KERB', 100, 190, 400, 30, road)

call assertEqual 'lane nested path', 'ROOT/ROAD/LANE', lane~pathId
call assertEqual 'road child count', 2, road~children~items

insideLane = .CameraBox~new('O1', 140, 140, 30, 20)
insideRoad = .CameraBox~new('O2', 160, 105, 30, 20)
outsideRoad = .CameraBox~new('O3', 20, 40, 30, 20)

call assertEqual 'deepest lane chosen', 'LANE', root~deepestContainingBox(insideLane)~id
call assertEqual 'road chosen outside lane', 'ROAD', root~deepestContainingBox(insideRoad)~id
call assertEqual 'root chosen outside road', 'ROOT', root~deepestContainingBox(outsideRoad)~id

track = .CameraTrack~new('TREL')
call addPoint track, 1000, 140, 140, 30, 20
call addPoint track, 1001, 150, 142, 30, 20
call addPoint track, 1002, 170, 145, 30, 20
/* Move out of LANE while remaining in ROAD. */
call addPoint track, 1003, 190, 108, 30, 20
call addPoint track, 1004, 200, 110, 30, 20

encoding = track~spatialRelationEncoding(root)
call assertEqual 'five samples encoded', 5, encoding~sampleCount
call assertEqual 'one region transition', 1, encoding~regionTransitionCount
call assertEqual 'five tokens emitted', 5, encoding~tokens~items

tokens = encoding~tokens
call assertEqual 'first token anchor', .CameraConstant~SPATIAL_TOKEN_ANCHOR, tokens[1]~kind
call assertEqual 'first token lane path', 'ROOT/ROAD/LANE', tokens[1]~regionPath
call assertEqual 'second token delta', .CameraConstant~SPATIAL_TOKEN_DELTA, tokens[2]~kind
call assertEqual 'third token delta', .CameraConstant~SPATIAL_TOKEN_DELTA, tokens[3]~kind
call assertEqual 'fourth token region transition', .CameraConstant~SPATIAL_TOKEN_REGION, tokens[4]~kind
call assertEqual 'fourth token road path', 'ROOT/ROAD', tokens[4]~regionPath
call assertEqual 'fifth token delta', .CameraConstant~SPATIAL_TOKEN_DELTA, tokens[5]~kind

relations = encoding~relations
call assertEqual 'relation lane path', 'ROOT/ROAD/LANE', relations[1]~regionPath
call assertEqual 'relation road path', 'ROOT/ROAD', relations[4]~regionPath
call assertTrue 'relative centre quantized to byte', relations[1]~centreX >= 0 & relations[1]~centreX <= 255
call assertTrue 'relative width quantized to byte', relations[1]~width > 0 & relations[1]~width <= 255

canonicalBefore = encoding~canonicalText
/* The encoding is a materialized relation stream; later source box mutation cannot move it. */
track~points[1]~box~x = 400
track~points[2]~box~y = 300
call assertEqual 'materialized spatial encoding stable', canonicalBefore, encoding~canonicalText

say '  relation stream:'
say encoding~canonicalText
say 'CAMERA SPATIAL RELATION SMOKE: OK'
exit 0

addPoint: procedure
  use arg track, timestamp, x, y, width, height
  observation = .CameraObservation~new(timestamp, .CameraBox~new('OBS', x, y, width, height), 1, 1)
  ignored = track~addObservation(observation)
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
