/* Graduated Camera assessment disclosure tests. */

say 'CAMERA GRADUATED DISCLOSURE SMOKE START'

camera = .CameraModel~new('CAMDISC', 640, 360)
camera~behaviour~addWindow(.CameraBehaviourWindow~new(43200, 1800))
weekday = .CameraConstant~DAY_WEEKDAY

do sample = 1 to 5
  second = 43100 + (sample * 20)
  ignored = camera~behaviour~observeMetric(second, 'TRACK_RATE', 20 + sample)
  ignored = camera~calendarBehaviour~observeMetric(weekday, camera~behaviour, second, 'TRACK_RATE', 20 + sample)
  ignored = camera~calendarBehaviour~observeSummary(weekday)
  ignored = camera~environmentModel~observeMetric(.CameraConstant~ENV_DAY_DIFFUSE, 'PHOTOMETRIC_RATE', 2 + (sample / 10))
end

ignoredToken = camera~tokenDictionary~tokenFor('ROUTE:R1')
ignoredToken = camera~tokenDictionary~tokenFor('ZONE:Z1')
g1 = camera~publishGeneration(44000)

summary = .CameraClipSummary~new('CLIP-DISC', 43100, 200)
summary~dayClass = weekday
summary~environmentCode = .CameraConstant~ENV_DAY_DIFFUSE
do n = 1 to 50
  ignoredTrack = summary~addTrack(.CameraTrack~new('TD' || n))
end

assessment = camera~assessSummaryAtGeneration(summary, 'G1', 3, 2.5)
publicView = assessment~disclosure('PUBLIC')
customerView = assessment~disclosure('CUSTOMER')
internalView = assessment~disclosure('INTERNAL')
fullView = assessment~disclosure('FULL')

call assertEqual 'public profile', 'PUBLIC', publicView~profile
call assertTrue 'public is compact signature', publicView~payload~pos('CAS') = 1
call assertTrue 'public hides expected values', publicView~payload~pos('expected=') = 0
call assertTrue 'public hides event grammar', publicView~payload~pos('EVENT_GRAMMAR=') = 0

call assertTrue 'customer exposes metric explanation', customerView~payload~pos('METRIC=TRACK_RATE') > 0
call assertTrue 'customer exposes expected value', customerView~payload~pos('expected=') > 0
call assertTrue 'customer hides contributing windows', customerView~payload~pos('WINDOW=') = 0
call assertTrue 'customer hides event grammar', customerView~payload~pos('EVENT_GRAMMAR=') = 0

call assertTrue 'internal exposes contributing windows', internalView~payload~pos('WINDOW=') > 0
call assertTrue 'internal exposes event grammar', internalView~payload~pos('EVENT_GRAMMAR=') > 0
call assertTrue 'internal exposes world counts', internalView~payload~pos('WORLD=') > 0
call assertTrue 'internal hides alchemy object id', internalView~payload~pos('ALCHEMY_OBJECT_ID=') = 0

call assertTrue 'full includes alchemy object id', fullView~payload~pos('ALCHEMY_OBJECT_ID=') > 0
call assertTrue 'full includes alchemy telemetry', fullView~payload~pos('ALCHEMY_USE_COUNT=') > 0
call assertTrue 'full includes instrumentation count', fullView~payload~pos('ALCHEMY_INSTRUMENTATION_EVENTS=') > 0

call assertTrue 'public smaller than customer', publicView~payloadBytes < customerView~payloadBytes
call assertTrue 'customer smaller than internal', customerView~payloadBytes < internalView~payloadBytes
call assertTrue 'internal smaller than full', internalView~payloadBytes < fullView~payloadBytes

/* Views are detached snapshots; later learner mutation cannot alter them. */
publicBefore = publicView~canonicalText
internalBefore = internalView~canonicalText
do sample = 1 to 8
  ignored = camera~calendarBehaviour~observeMetric(weekday, camera~behaviour, 43200, 'TRACK_RATE', 999)
  ignored = camera~calendarBehaviour~observeSummary(weekday)
end
ignoredToken = camera~tokenDictionary~tokenFor('MOTIF:M77')
camera~eventGrammar~stopDistance = camera~eventGrammar~stopDistance + 100

call assertEqual 'public disclosure immutable', publicBefore, publicView~canonicalText
call assertEqual 'internal disclosure immutable', internalBefore, internalView~canonicalText

say '  disclosure bytes P/C/I/F:' publicView~payloadBytes customerView~payloadBytes internalView~payloadBytes fullView~payloadBytes
say 'CAMERA GRADUATED DISCLOSURE SMOKE: OK'
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
