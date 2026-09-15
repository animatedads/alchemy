/* Immutable learned-generation and pinned matching tests. */

say 'CAMERA LEARNED GENERATION SMOKE START'

camera = .CameraModel~new('CAMGEN', 640, 360)
root = camera~rootRegion
road = .CameraBox~new('ROAD', 100, 100, 400, 120, root)
lane = .CameraBox~new('LANE', 100, 130, 400, 60, road)

t1 = buildTrack('T1', 1000, 140, 140, 10, 2, 30, 20)
learn1 = camera~learnSpatialPrimitive(t1)
call assertEqual 'first live primitive', 'SBP1', learn1~primitiveId

g1 = camera~publishGeneration(1100)
call assertEqual 'first generation id', 'G1', g1~id
call assertEqual 'g1 published', .CameraConstant~GENERATION_PUBLISHED, g1~state
call assertEqual 'g1 one primitive', 1, g1~primitiveCount

/* Similar movement is read against the frozen generation, not learned into it. */
t2 = buildTrack('T2', 1200, 143, 141, 11, 2, 30, 20)
gm1 = camera~matchSpatialPrimitive(t2, 'G1')
call assertEqual 'g1 known match', .CameraConstant~SPATIAL_MATCH_KNOWN, gm1~state
call assertEqual 'g1 matches SBP1', 'SBP1', gm1~primitiveId
call assertTrue 'generation provenance retained', gm1~evidenceText~pos('generation=G1') > 0
call assertEqual 'g1 still one primitive after read', 1, g1~primitiveCount

/* Learning remains a separate explicit mutation of the live model. */
t3 = buildTrack('T3', 1300, 300, 135, -5, 0, 180, 50)
learn2 = camera~learnSpatialPrimitive(t3)
call assertEqual 'second live primitive', 'SBP2', learn2~primitiveId
call assertEqual 'live model now two primitives', 2, camera~spatialPrimitiveModel~primitiveCount
call assertEqual 'g1 stays frozen at one primitive', 1, g1~primitiveCount

/* The old generation cannot silently learn the new movement. */
g1Miss = camera~matchSpatialPrimitive(t3, 'G1')
call assertEqual 'g1 new movement unmatched', .CameraConstant~SPATIAL_MATCH_UNMATCHED, g1Miss~state
call assertEqual 'g1 unmatched has no primitive id', '', g1Miss~primitiveId
call assertEqual 'g1 still one primitive after miss', 1, g1~primitiveCount

g1Canonical = g1~canonicalText

/* Publishing G2 freezes the newer learned world and supersedes G1. */
g2 = camera~publishGeneration(1400)
call assertEqual 'second generation id', 'G2', g2~id
call assertEqual 'g2 has two primitives', 2, g2~primitiveCount
call assertEqual 'g1 superseded', .CameraConstant~GENERATION_SUPERSEDED, g1~state
call assertEqual 'g2 current', 'G2', camera~currentGeneration~id
call assertEqual 'registry count', 2, camera~generationRegistry~generationCount

g2Match = camera~matchSpatialPrimitive(t3, 'G2')
call assertEqual 'g2 knows second movement', .CameraConstant~SPATIAL_MATCH_KNOWN, g2Match~state
call assertEqual 'g2 matches SBP2', 'SBP2', g2Match~primitiveId

/* Later live learning cannot alter either published generation content. */
t4 = buildTrack('T4', 1500, 160, 105, 7, 1, 30, 20)
ignored = camera~learnSpatialPrimitive(t4)
call assertEqual 'published g2 remains two primitives', 2, g2~primitiveCount
call assertTrue 'g1 semantic primitive content stable', g1~canonicalText~pos('primitive=SBP1') > 0
call assertEqual 'g1 identity remains addressable', 'G1', camera~generation('G1')~id

say '  g1 match:' gm1~evidenceText
say '  g1 miss: ' g1Miss~evidenceText
say '  g2 match:' g2Match~evidenceText
say 'CAMERA LEARNED GENERATION SMOKE: OK'
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
