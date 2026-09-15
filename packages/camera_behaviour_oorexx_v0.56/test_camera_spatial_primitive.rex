/* Recurrent spatial behaviour primitive and provenance tests. */

say 'CAMERA SPATIAL PRIMITIVE SMOKE START'

camera = .CameraModel~new('CAMSBP', 640, 360)
root = camera~rootRegion
road = .CameraBox~new('ROAD', 100, 100, 400, 120, root)
lane = .CameraBox~new('LANE', 100, 130, 400, 60, road)

t1 = buildTrack('T1', 1000, 140, 140, 10, 2)
m1 = camera~learnSpatialPrimitive(t1)
call assertEqual 'first match new', .CameraConstant~SPATIAL_MATCH_NEW, m1~state
call assertEqual 'first primitive id', 'SBP1', m1~primitiveId
call assertEqual 'one primitive', 1, camera~spatialPrimitiveModel~primitiveCount
call assertTrue 'source encoding id retained', m1~sourceEncodingId~pos('T1@') = 1
call assertEqual 'source track retained', 'T1', m1~sourceTrackId
call assertTrue 'evidence carries structure', m1~evidenceText~pos('structure=') > 0

/* Same nested movement with small geometric differences should reuse SBP1. */
t2 = buildTrack('T2', 2000, 143, 141, 11, 2)
m2 = camera~learnSpatialPrimitive(t2)
call assertEqual 'second match known', .CameraConstant~SPATIAL_MATCH_KNOWN, m2~state
call assertEqual 'same primitive reused', 'SBP1', m2~primitiveId
call assertTrue 'small residual explicit', m2~residual > 0
call assertTrue 'small residual under tolerance', m2~residual <= camera~spatialPrimitiveModel~matchTolerance
call assertEqual 'still one primitive', 1, camera~spatialPrimitiveModel~primitiveCount
p1 = camera~spatialPrimitiveModel~primitives[1]
call assertEqual 'primitive learned recurrence', .CameraConstant~SPATIAL_PRIMITIVE_KNOWN, p1~state
call assertEqual 'primitive sample count', 2, p1~sampleCount

/* Same region grammar but wildly different geometry creates a second primitive. */
t3 = .CameraTrack~new('T3')
do pointIndex = 0 to 4
  call addPoint t3, 3000 + pointIndex, 300 - (5 * pointIndex), 135, 180, 50
end
m3 = camera~learnSpatialPrimitive(t3)
call assertEqual 'distant movement new', .CameraConstant~SPATIAL_MATCH_NEW, m3~state
call assertEqual 'second primitive created', 'SBP2', m3~primitiveId
call assertEqual 'two primitives', 2, camera~spatialPrimitiveModel~primitiveCount

/* Different region transition grammar cannot match SBP1 even if coordinates start nearby. */
t4 = .CameraTrack~new('T4')
call addPoint t4, 4000, 140, 140, 30, 20
call addPoint t4, 4001, 155, 142, 30, 20
call addPoint t4, 4002, 190, 108, 30, 20
m4 = camera~learnSpatialPrimitive(t4)
call assertEqual 'different grammar new', .CameraConstant~SPATIAL_MATCH_NEW, m4~state
call assertEqual 'third primitive created', 'SBP3', m4~primitiveId

/* Match evidence is immutable after source track mutation. */
evidenceBefore = m2~canonicalText
t2~points[1]~box~x = 500
t2~points[2]~box~y = 320
call assertEqual 'match provenance immutable', evidenceBefore, m2~canonicalText

say '  first:' m1~evidenceText
say '  reuse:' m2~evidenceText
say '  model:'
say camera~spatialPrimitiveModel~canonicalText
say 'CAMERA SPATIAL PRIMITIVE SMOKE: OK'
exit 0

buildTrack: procedure
  use arg id, startTimestamp, startX, startY, stepX, stepY
  track = .CameraTrack~new(id)
  do pointIndex = 0 to 4
    call addPoint track, startTimestamp + pointIndex, startX + (stepX * pointIndex), startY + (stepY * pointIndex), 30, 20
  end
  return track

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
