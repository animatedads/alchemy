/* Generation-pinned assessment evidence tests. */

say 'CAMERA ASSESSMENT EVIDENCE SMOKE START'

camera = .CameraModel~new('CAMEVID', 640, 360)
camera~behaviour~addWindow(.CameraBehaviourWindow~new(42300, 1800))
camera~behaviour~addWindow(.CameraBehaviourWindow~new(43200, 1800))
camera~behaviour~addWindow(.CameraBehaviourWindow~new(44100, 1800))

weekday = .CameraConstant~DAY_WEEKDAY
do sample = 1 to 5
  second = 43100 + (sample * 20)
  ignored = camera~behaviour~observeMetric(second, 'TRACK_RATE', 10 + sample)
  ignored = camera~calendarBehaviour~observeMetric(weekday, camera~behaviour, second, 'TRACK_RATE', 20 + sample)
  ignored = camera~calendarBehaviour~observeSummary(weekday)
  ignored = camera~environmentModel~observeMetric(.CameraConstant~ENV_DAY_DIFFUSE, 'PHOTOMETRIC_RATE', 2 + (sample / 10))
end

/* Give the frozen world a little structural vocabulary so evidence counts are meaningful. */
ignoredToken = camera~tokenDictionary~tokenFor('ROUTE:R1')
ignoredToken = camera~tokenDictionary~tokenFor('ZONE:Z1')
track = .CameraTrack~new('TLEARN')
do n = 0 to 4
  obs = .CameraObservation~new(42000+n, .CameraBox~new('OBS', 100+(n*10), 120, 30, 20), 1, 1)
  ignoredPoint = track~addObservation(obs)
end
ignoredPrimitive = camera~learnSpatialPrimitive(track)
ignoredRoute = camera~routeModel~learnTrack(track)
ignoredZones = camera~spatialModel~learnTrackEndpoints(track)

g1 = camera~publishGeneration(44000)

summary = .CameraClipSummary~new('CLIP-EVID', 43100, 200)
summary~dayClass = weekday
summary~environmentCode = .CameraConstant~ENV_DAY_DIFFUSE
do n = 1 to 50
  ignoredTrack = summary~addTrack(.CameraTrack~new('TX' || n))
end

assessment = camera~assessSummaryAtGeneration(summary, 'G1', 3, 2.5)
evidence = assessment~evidence

call assertTrue 'evidence attached', evidence \== .nil
call assertEqual 'evidence generation', 'G1', evidence~generationId
call assertEqual 'evidence clip', 'CLIP-EVID', evidence~clipId
call assertEqual 'evidence day class', weekday, evidence~dayClass
call assertEqual 'evidence environment', .CameraConstant~ENV_DAY_DIFFUSE, evidence~environmentCode
call assertEqual 'all assessed metrics represented', assessment~metrics~items, evidence~metricCount
call assertTrue 'structural primitive count carried', evidence~primitiveCount >= 1
call assertTrue 'structural route count carried', evidence~routeCount >= 1
call assertTrue 'structural zone count carried', evidence~zoneCount >= 1
call assertEqual 'token dictionary count carried', 2, evidence~tokenCount
call assertTrue 'event grammar retained', evidence~eventGrammarText~length > 0

trackEvidence = evidence~metric('TRACK_RATE')
call assertTrue 'track evidence present', trackEvidence \== .nil
call assertEqual 'weekday family explicit', 'DAY', trackEvidence~baselineFamily
call assertEqual 'weekday context explicit', 'DAY:' || weekday, trackEvidence~baselineContext
call assertTrue 'overlapping contributing windows retained', trackEvidence~windowCount >= 2
call assertEqual 'metric observed agrees', assessment~metric('TRACK_RATE')~value, trackEvidence~observed
call assertEqual 'metric expected agrees', assessment~metric('TRACK_RATE')~expected, trackEvidence~expected
call assertEqual 'metric z agrees', assessment~metric('TRACK_RATE')~zScore, trackEvidence~zScore

photoEvidence = evidence~metric('PHOTOMETRIC_RATE')
call assertEqual 'environment family explicit', 'ENV', photoEvidence~baselineFamily
call assertEqual 'environment code explicit', .CameraConstant~ENV_DAY_DIFFUSE, photoEvidence~environmentCode
call assertEqual 'environment has no time-window list', 0, photoEvidence~windowCount

canonicalBefore = evidence~canonicalText

/* Radical live mutations cannot rewrite detached assessment evidence. */
do sample = 1 to 10
  ignored = camera~calendarBehaviour~observeMetric(weekday, camera~behaviour, 43200, 'TRACK_RATE', 1000)
  ignored = camera~calendarBehaviour~observeSummary(weekday)
  ignored = camera~environmentModel~observeMetric(.CameraConstant~ENV_DAY_DIFFUSE, 'PHOTOMETRIC_RATE', 500)
end
ignoredToken = camera~tokenDictionary~tokenFor('MOTIF:M99')
camera~eventGrammar~stopDistance = camera~eventGrammar~stopDistance + 500

call assertEqual 'evidence canonical identity remains frozen', canonicalBefore, evidence~canonicalText
call assertEqual 'old token count remains frozen', 2, evidence~tokenCount

g2 = camera~publishGeneration(45000)
assessment2 = camera~assessSummaryAtGeneration(summary, 'G2', 3, 2.5)
call assertEqual 'new evidence generation', 'G2', assessment2~evidence~generationId
call assertTrue 'new world has larger token dictionary', assessment2~evidence~tokenCount > evidence~tokenCount
call assertTrue 'new baseline differs from old evidence', assessment2~evidence~metric('TRACK_RATE')~expected \= trackEvidence~expected

say '  TRACK_RATE windows:' trackEvidence~windowCount
say '  G1 evidence world:' evidence~regionCount evidence~zoneCount evidence~routeCount evidence~primitiveCount evidence~tokenCount
say 'CAMERA ASSESSMENT EVIDENCE SMOKE: OK'
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
