/* Overlapping compact-signature trend model tests. */

say 'CAMERA SIGNATURE TREND SMOKE START'

model = .CameraSignatureTrendModel~new(.array~of(300, 900, 3600), 3, 16)

/* A steady five-minute sequence should remain stable. */
do n = 0 to 3
  assessment = makeAssessment('C' || n, 43200 + (n * 60), 'G1', .CameraConstant~DAY_WEEKDAY, .CameraConstant~ENV_DAY_DIFFUSE, 0.5, 0.2)
  stableSnapshot = model~observe(assessment~conditionSignature)
end
call assertEqual 'stable strongest delta under threshold', .CameraConstant~TREND_STABLE, stableSnapshot~window(300)~metric('TRACK_RATE')~trendState
call assertEqual 'three windows emitted', 3, stableSnapshot~windows~items

/* Sustained track-rate rise: short window reacts, longer windows retain more history. */
assessment = makeAssessment('C4', 43440, 'G1', .CameraConstant~DAY_WEEKDAY, .CameraConstant~ENV_DAY_DIFFUSE, 3.5, 0.2)
s4 = model~observe(assessment~conditionSignature)
assessment = makeAssessment('C5', 43500, 'G1', .CameraConstant~DAY_WEEKDAY, .CameraConstant~ENV_DAY_DIFFUSE, 5.0, 0.2)
s5 = model~observe(assessment~conditionSignature)

tr300 = s5~window(300)~metric('TRACK_RATE')
tr900 = s5~window(900)~metric('TRACK_RATE')
ph300 = s5~window(300)~metric('PHOTOMETRIC_RATE')

call assertEqual 'short track trend rising', .CameraConstant~TREND_RISING, tr300~trendState
call assertEqual 'medium track trend rising', .CameraConstant~TREND_RISING, tr900~trendState
call assertEqual 'photometric remains stable', .CameraConstant~TREND_STABLE, ph300~trendState
call assertEqual 'strongest metric is track rate', 'TRACK_RATE', s5~strongestMetricName
call assertTrue 'trend compact form is tiny', length(s5~compactText) < 220

/* Context boundaries reset comparison population rather than masquerading as trend. */
night = makeAssessment('N1', 43560, 'G1', .CameraConstant~DAY_WEEKDAY, .CameraConstant~ENV_NIGHT_ARTIFICIAL, 5.2, 4.0)
nightSnapshot = model~observe(night~conditionSignature)
call assertEqual 'night five-minute window has one sample', 1, nightSnapshot~window(300)~sampleCount
call assertEqual 'night insufficient for rising trend', .CameraConstant~TREND_STABLE, nightSnapshot~window(300)~metric('TRACK_RATE')~trendState

/* Generation changes also isolate history. */
newGeneration = makeAssessment('G2C1', 43620, 'G2', .CameraConstant~DAY_WEEKDAY, .CameraConstant~ENV_NIGHT_ARTIFICIAL, 8.0, 4.0)
g2Snapshot = model~observe(newGeneration~conditionSignature)
call assertEqual 'new generation isolated', 1, g2Snapshot~window(3600)~sampleCount
call assertEqual 'new generation retained', 'G2', g2Snapshot~generationId

/* Camera facade records trend instrumentation over real assessment objects. */
camera = .CameraModel~new('CAMTREND', 640, 360)
a1 = makeAssessment('F1', 50000, 'G9', .CameraConstant~DAY_WEEKDAY, .CameraConstant~ENV_DAY_DIFFUSE, 0.0, 0.0)
a2 = makeAssessment('F2', 50060, 'G9', .CameraConstant~DAY_WEEKDAY, .CameraConstant~ENV_DAY_DIFFUSE, 1.0, 0.0)
a3 = makeAssessment('F3', 50120, 'G9', .CameraConstant~DAY_WEEKDAY, .CameraConstant~ENV_DAY_DIFFUSE, 4.0, 0.0)
ignored = camera~observeAssessmentTrend(a1)
ignored = camera~observeAssessmentTrend(a2)
facadeTrend = camera~observeAssessmentTrend(a3)
call assertEqual 'facade trend rising', .CameraConstant~TREND_RISING, facadeTrend~window(300)~metric('TRACK_RATE')~trendState
call assertTrue 'trend instrumentation emitted', camera~instrumentationEvents~items >= 3

say '  trend compact:' s5~compactText
say '  300s TRACK first/last/delta:' tr300~firstQuantizedZ tr300~lastQuantizedZ tr300~deltaZ
say 'CAMERA SIGNATURE TREND SMOKE: OK'
exit 0

makeAssessment: procedure
  use arg clipId, secondOfDay, generationId, dayClass, environmentCode, trackZ, photoZ
  assessment = .CameraClipAssessment~new(clipId, secondOfDay, dayClass, generationId)

  if abs(trackZ) >= 2.5 then trackState = .CameraConstant~BASELINE_ELEVATED
  else trackState = .CameraConstant~BASELINE_WITHIN
  if abs(photoZ) >= 2.5 then photoState = .CameraConstant~BASELINE_ELEVATED
  else photoState = .CameraConstant~BASELINE_WITHIN

  trackMetric = .CameraMetricAssessment~new('TRACK_RATE', trackZ, 0, trackZ, 10, trackState, 'DAY:' || dayClass)
  photoMetric = .CameraMetricAssessment~new('PHOTOMETRIC_RATE', photoZ, 0, photoZ, 10, photoState, 'ENV:' || environmentCode)
  ignored = assessment~addMetric(trackMetric)
  ignored = assessment~addMetric(photoMetric)

  /* Signature reads environment code from assessment evidence. Use the smallest truthful stub. */
  assessment~evidence = .CameraSignatureTestEvidence~new(environmentCode)
  return assessment

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

::class CameraSignatureTestEvidence public
::attribute environmentCode get
::method init
  expose environmentCode
  use arg code
  environmentCode = code

::requires 'CameraCore.cls'
