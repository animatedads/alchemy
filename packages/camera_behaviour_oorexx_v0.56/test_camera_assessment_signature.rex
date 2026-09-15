/* Tiny generation-pinned condition signature and delta tests. */

say 'CAMERA ASSESSMENT SIGNATURE SMOKE START'

camera = .CameraModel~new('CAMSIG', 640, 360)
camera~behaviour~addWindow(.CameraBehaviourWindow~new(43200, 3600))
weekday = .CameraConstant~DAY_WEEKDAY

do sample = 1 to 7
  second = 43100 + sample
  ignored = camera~calendarBehaviour~observeMetric(weekday, camera~behaviour, second, 'TRACK_RATE', 10 + (sample // 2))
  ignored = camera~calendarBehaviour~observeMetric(weekday, camera~behaviour, second, 'EVENT_RATE', 5 + (sample // 2))
  ignored = camera~calendarBehaviour~observeSummary(weekday)
end

g1 = camera~publishGeneration(44000)

quiet = .CameraClipSummary~new('QUIET', 43100, 300)
quiet~dayClass = weekday
quiet~environmentCode = .CameraConstant~ENV_DAY_DIFFUSE
do n = 1 to 55
  ignoredTrack = quiet~addTrack(.CameraTrack~new('Q' || n))
end

busy = .CameraClipSummary~new('BUSY', 43100, 300)
busy~dayClass = weekday
busy~environmentCode = .CameraConstant~ENV_DAY_DIFFUSE
do n = 1 to 100
  ignoredTrack = busy~addTrack(.CameraTrack~new('B' || n))
end

quietAssessment = camera~assessSummaryAtGeneration(quiet, 'G1', 3, 2.5)
busyAssessment = camera~assessSummaryAtGeneration(busy, 'G1', 3, 2.5)
quietSignature = quietAssessment~conditionSignature
busySignature = busyAssessment~conditionSignature

call assertEqual 'signature version', '1', quietSignature~version
call assertEqual 'signature generation', 'G1', quietSignature~generationId
call assertEqual 'signature metric count', quietAssessment~metrics~items, quietSignature~metricCount
call assertTrue 'compact signature materially smaller than evidence', quietSignature~compactText~length < quietAssessment~evidence~canonicalText~length
call assertEqual 'track metric code', 'TR', quietSignature~metric('TRACK_RATE')~code

sameDelta = quietSignature~compareTo(quietAssessment~conditionSignature)
call assertEqual 'same signature max delta zero', 0, sameDelta~maximumAbsoluteDeltaZ
call assertEqual 'same signature state changes zero', 0, sameDelta~changedStateCount
call assertEqual 'same signature generation unchanged', .false, sameDelta~generationChanged

change = quietSignature~compareTo(busySignature)
call assertEqual 'same generation', .false, change~generationChanged
call assertTrue 'track rate changes', change~metric('TRACK_RATE')~deltaZ \= 0
call assertTrue 'maximum delta nonzero', change~maximumAbsoluteDeltaZ > 0
call assertTrue 'mean delta nonzero', change~meanAbsoluteDeltaZ > 0

/* Publishing a new generation marks model drift separately from scene drift. */
do sample = 1 to 8
  ignored = camera~calendarBehaviour~observeMetric(weekday, camera~behaviour, 43200, 'TRACK_RATE', 100)
  ignored = camera~calendarBehaviour~observeSummary(weekday)
end
g2 = camera~publishGeneration(45000)
quietG2 = camera~assessSummaryAtGeneration(quiet, 'G2', 3, 2.5)~conditionSignature
modelDelta = quietSignature~compareTo(quietG2)
call assertEqual 'generation change explicit', .true, modelDelta~generationChanged
call assertTrue 'generation change can alter residual vector', modelDelta~metric('TRACK_RATE')~deltaZ \= 0

/* Different context is also explicit, not silently treated as scene movement. */
night = .CameraClipSummary~new('NIGHT', 43100, 300)
night~dayClass = .CameraConstant~DAY_WEEKEND
night~environmentCode = .CameraConstant~ENV_NIGHT_ARTIFICIAL
do n = 1 to 55
  ignoredTrack = night~addTrack(.CameraTrack~new('N' || n))
end
nightSignature = camera~assessSummaryAtGeneration(night, 'G1', 3, 2.5)~conditionSignature
contextDelta = quietSignature~compareTo(nightSignature)
call assertEqual 'day change explicit', .true, contextDelta~dayClassChanged
call assertEqual 'environment change explicit', .true, contextDelta~environmentChanged

say '  signature bytes:' quietSignature~compactText~length
say '  evidence bytes: ' quietAssessment~evidence~canonicalText~length
say '  movement delta:  ' change~compactText
say 'CAMERA ASSESSMENT SIGNATURE SMOKE: OK'
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
