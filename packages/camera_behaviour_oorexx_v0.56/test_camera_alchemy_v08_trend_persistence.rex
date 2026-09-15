/* Alchemy Objects v0.8 adoption + compact trend persistence tests. */

say 'CAMERA ALCHEMY V0.8 TREND PERSISTENCE SMOKE START'

camera = .CameraModel~new('CAM40', 640, 360)
verifyCamera = .AlchemyAdoptionVerifier~verify(camera, 'STANDARD')
call assertTrue 'CameraModel standard adoption', verifyCamera~ok
construction = camera~alchemyConstructionProvenance
call assertEqual 'CameraModel preferred INIT entrypoint', 'INIT', construction['entrypoint']
call assertEqual 'CameraModel base v0.8', '0.8', construction['base_version']

generation = camera~publishGeneration(1000)
verifyGeneration = .AlchemyAdoptionVerifier~verify(generation, 'STANDARD')
call assertTrue 'generation standard adoption', verifyGeneration~ok
call assertEqual 'generation preferred INIT entrypoint', 'INIT', generation~alchemyConstructionProvenance['entrypoint']

summary = .CameraClipSummary~new('C40', 1000, 60)
summary~dayClass = .CameraConstant~DAY_WEEKDAY
summary~environmentCode = .CameraConstant~ENV_DAY_DIFFUSE
assessment = .CameraGenerationClipComparator~assess(generation, summary, 1, 2.5)
verifyEvidence = .AlchemyAdoptionVerifier~verify(assessment~evidence, 'STANDARD')
call assertTrue 'assessment evidence standard adoption', verifyEvidence~ok
call assertEqual 'evidence preferred INIT entrypoint', 'INIT', assessment~evidence~alchemyConstructionProvenance['entrypoint']

/* Trend persistence: two shifted snapshots => persistent regime, then two stable => recovered/closed. */
persist = .CameraSignatureTrendPersistenceModel~new(2, 2, 2)

c1 = persist~observe(makeTrend(2000, 'G1', 3, 'TRACK_RATE', 20))
call assertEqual 'first shifted emerging', .CameraConstant~SIGNATURE_TREND_PHASE_EMERGING, c1~phase
c2 = persist~observe(makeTrend(2060, 'G1', 3, 'TRACK_RATE', 28))
call assertEqual 'second shifted persistent', .CameraConstant~SIGNATURE_TREND_PHASE_PERSISTENT, c2~phase
call assertTrue 'persistent regime id allocated', c2~regimeId \= ''
call assertTrue 'active regime exists', persist~activeRegime \== .nil

c3 = persist~observe(makeTrend(2120, 'G1', 0, '', 0))
call assertEqual 'first expected recovering', .CameraConstant~SIGNATURE_TREND_PHASE_RECOVERING, c3~phase
c4 = persist~observe(makeTrend(2180, 'G1', 0, '', 0))
call assertEqual 'second expected stable', .CameraConstant~SIGNATURE_TREND_PHASE_STABLE, c4~phase
call assertTrue 'regime closed', persist~activeRegime == .nil
call assertEqual 'one completed trend regime', 1, persist~completedRegimes~items
call assertEqual 'closed regime state', .CameraConstant~SIGNATURE_TREND_REGIME_CLOSED, persist~completedRegimes[1]~state

/* Context changes cannot extend a regime across learned-world/environment boundaries. */
c5 = persist~observe(makeTrend(2240, 'G2', 3, 'TRACK_RATE', 30))
call assertEqual 'new context starts emerging', .CameraConstant~SIGNATURE_TREND_PHASE_EMERGING, c5~phase
call assertEqual 'new context has no old regime id', '', c5~regimeId

say '  Camera adoption level:' verifyCamera~level
say '  trend condition:' c2~compactText
say 'CAMERA ALCHEMY V0.8 TREND PERSISTENCE SMOKE: OK'
exit 0

makeTrend: procedure
  use arg timestamp, generationId, trendingWindowCount, strongestMetricName, strongestDelta
  windows = .array~new
  do span over .array~of(300,900,3600)
    /* Build a minimal trend window by manufacturing three signatures. */
    signatures = .array~new
    do n = 0 to 2
      assessment = .CameraClipAssessment~new('X' || n, timestamp - ((2-n)*30), .CameraConstant~DAY_WEEKDAY, generationId)
      z = 0
      if trendingWindowCount > 0 then z = (n * strongestDelta) / 16
      state = .CameraConstant~BASELINE_WITHIN
      if abs(z) >= 2.5 then state = .CameraConstant~BASELINE_ELEVATED
      metric = .CameraMetricAssessment~new('TRACK_RATE', z, 0, z, 10, state, 'DAY:121')
      ignored = assessment~addMetric(metric)
      assessment~evidence = .C40Environment~new(.CameraConstant~ENV_DAY_DIFFUSE)
      signatures~append(assessment~conditionSignature)
    end
    window = .CameraSignatureTrendWindowSnapshot~new(span, signatures, 3, 16)
    windows~append(window)
  end
  trend = .CameraSignatureTrendSnapshot~new(signatures[signatures~items], windows)
  /* The natural builder yields all three windows trending when requested. */
  return trend

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

::class C40Environment public
::attribute environmentCode get
::method init
  expose environmentCode
  use arg code
  environmentCode = code

::requires 'CameraCore.cls'
::requires 'AlchemyAdoption.cls'
