/* Frozen-generation clip assessment tests. */

say 'CAMERA GENERATION ASSESSMENT SMOKE START'

camera = .CameraModel~new('CAMASSESS', 640, 360)
camera~behaviour~addWindow(.CameraBehaviourWindow~new(43200, 3600))

/* Learn stable global + weekday + environment baselines. */
do sample = 1 to 5
  second = 43000 + sample
  ignored = camera~behaviour~observeMetric(second, 'TRACK_RATE', 10 + sample - 3)
  ignored = camera~calendarBehaviour~observeMetric(.CameraConstant~DAY_WEEKDAY, camera~behaviour, second, 'TRACK_RATE', 20 + sample - 3)
  ignored = camera~calendarBehaviour~observeSummary(.CameraConstant~DAY_WEEKDAY)
  ignored = camera~environmentModel~observeMetric(.CameraConstant~ENV_DAY_DIFFUSE, 'PHOTOMETRIC_RATE', 2 + (sample / 10))
end

g1 = camera~publishGeneration(44000)
call assertEqual 'generation schema', '6', g1~version

summary = .CameraClipSummary~new('CLIP-A', 43100, 200)
summary~dayClass = .CameraConstant~DAY_WEEKDAY
summary~environmentCode = .CameraConstant~ENV_DAY_DIFFUSE

/* Build the values without needing image processing: 50 tracks in 200 s = 15/min. */
do n = 1 to 50
  track = .CameraTrack~new('T' || n)
  ignoredTrack = summary~addTrack(track)
end

a1 = .CameraGenerationClipComparator~assess(g1, summary, 3, 2.5)
call assertEqual 'assessment pinned to G1', 'G1', a1~generationId
call assertEqual 'weekday baseline selected', 'DAY:' || .CameraConstant~DAY_WEEKDAY, a1~metric('TRACK_RATE')~baselineContext
g1Expected = a1~metric('TRACK_RATE')~expected
g1State = a1~metric('TRACK_RATE')~state

/* Dramatically change the live baselines after G1. */
do sample = 1 to 8
  ignored = camera~behaviour~observeMetric(43200, 'TRACK_RATE', 100)
  ignored = camera~calendarBehaviour~observeMetric(.CameraConstant~DAY_WEEKDAY, camera~behaviour, 43200, 'TRACK_RATE', 100)
  ignored = camera~calendarBehaviour~observeSummary(.CameraConstant~DAY_WEEKDAY)
  ignored = camera~environmentModel~observeMetric(.CameraConstant~ENV_DAY_DIFFUSE, 'PHOTOMETRIC_RATE', 50)
end

/* Reassessment against G1 must be identical despite live learning. */
a1Again = .CameraGenerationClipComparator~assess(g1, summary, 3, 2.5)
call assertEqual 'G1 expected value stable', g1Expected, a1Again~metric('TRACK_RATE')~expected
call assertEqual 'G1 state stable', g1State, a1Again~metric('TRACK_RATE')~state

g2 = camera~publishGeneration(45000)
a2 = .CameraGenerationClipComparator~assess(g2, summary, 3, 2.5)
call assertEqual 'assessment pinned to G2', 'G2', a2~generationId
call assertTrue 'G2 baseline changed', a2~metric('TRACK_RATE')~expected \= g1Expected

/* Camera facade can replay explicitly against an old generation. */
facadeOld = camera~assessSummaryAtGeneration(summary, 'G1', 3, 2.5)
facadeNew = camera~assessSummaryAtGeneration(summary, 'G2', 3, 2.5)
call assertEqual 'facade old generation', 'G1', facadeOld~generationId
call assertEqual 'facade new generation', 'G2', facadeNew~generationId
call assertEqual 'facade old expected', g1Expected, facadeOld~metric('TRACK_RATE')~expected
call assertTrue 'facade generations differ', facadeOld~metric('TRACK_RATE')~expected \= facadeNew~metric('TRACK_RATE')~expected

say '  G1 TRACK_RATE expected/state:' facadeOld~metric('TRACK_RATE')~expected facadeOld~metric('TRACK_RATE')~state
say '  G2 TRACK_RATE expected/state:' facadeNew~metric('TRACK_RATE')~expected facadeNew~metric('TRACK_RATE')~state
say 'CAMERA GENERATION ASSESSMENT SMOKE: OK'
exit 0

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
