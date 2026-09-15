/* Longer behavioural motif grammar tests for CameraCore.cls */

say 'CAMERA MOTIF SMOKE START'

camera = .CameraModel~new('CAMMOTIF', 640, 360)
summary1 = makeSummary('M1')
encodings1 = camera~motifModel~recogniseAndLearnSummary(summary1)
call assertEqual 'one motif candidate first pass', 1, encodings1~items
call assertEqual 'first motif literal', .CameraConstant~MOTIF_NEW, encodings1[1]~state
call assertEqual 'motif learned', 1, camera~motifModel~motifCount
call assertEqual 'summary motif occurrence', 1, summary1~motifCount

summary2 = makeSummary('M2')
encodings2 = camera~motifModel~recogniseAndLearnSummary(summary2)
call assertEqual 'second pass still literal until repeated support', .CameraConstant~MOTIF_NEW, encodings2[1]~state

summary3 = makeSummary('M3')
encodings3 = camera~motifModel~recogniseAndLearnSummary(summary3)
call assertEqual 'third pass known motif', .CameraConstant~MOTIF_KNOWN, encodings3[1]~state
call assertTrue 'known motif cheaper', encodings3[1]~encodedBits < encodings3[1]~literalBits
call assertEqual 'same motif identity', 'M1', encodings3[1]~motifId

/* A changed spatial grammar must not be folded into M1. */
oddSummary = makeOddSummary('ODD')
oddEncodings = camera~motifModel~recogniseAndLearnSummary(oddSummary)
call assertEqual 'changed stop zone creates another motif', 2, camera~motifModel~motifCount
call assertTrue 'odd motif differs', oddEncodings[1]~motifId \= 'M1'

/* Participant identities do not enter the motif key. */
summary4 = makeSummaryWithTracks('M4', 'T91', 'T92')
encodings4 = camera~motifModel~recogniseAndLearnSummary(summary4)
call assertEqual 'different participants reuse motif', 'M1', encodings4[1]~motifId

/* Persistence retains motif identity and support. */
path = 'camera_motif_test.model'
dropValue = .CameraModelPersistence~save(camera, path)
restored = .CameraModelPersistence~load(path)
call assertEqual 'motif count survives', camera~motifModel~motifCount, restored~motifModel~motifCount
knownMotif = camera~motifModel~motifForId('M1')
restoredMotif = restored~motifModel~motifForId('M1')
call assertTrue 'restored M1 exists', restoredMotif \== .nil
call assertEqual 'support survives', knownMotif~sampleCount, restoredMotif~sampleCount
call assertEqual 'sequence survives', knownMotif~sequenceKey, restoredMotif~sequenceKey
call sysfiledelete path

say 'CAMERA MOTIF SMOKE: OK'
exit 0

makeSummary: procedure
  use arg clipId
  return makeSummaryWithTracks(clipId, 'T1', 'T2')

makeSummaryWithTracks: procedure
  use arg clipId, trackA, trackB
  summary = .CameraClipSummary~new(clipId, 900, 60, .CameraConstant~ENV_NIGHT_ARTIFICIAL, .CameraConstant~DAY_WEEKEND)
  exitEvent = .CameraEvent~new('E4', .CameraConstant~EVENT_EXIT, 930, trackA)
  exitEvent~routeId = 'R7'
  exitEvent~zoneId = 'Z8'
  summary~addEvent(exitEvent)

  enterEvent = .CameraEvent~new('E1', .CameraConstant~EVENT_ENTER, 901, trackA)
  enterEvent~routeId = 'R7'
  enterEvent~zoneId = 'Z3'
  summary~addEvent(enterEvent)

  stopEvent = .CameraEvent~new('E2', .CameraConstant~EVENT_STOP, 910, trackA)
  stopEvent~routeId = 'R7'
  stopEvent~zoneId = 'Z6'
  summary~addEvent(stopEvent)

  pairEvent = .CameraEvent~new('E3', .CameraConstant~EVENT_CLOSE, 915, trackA, trackB)
  pairEvent~episodeId = 'EP1'
  pairEvent~episodeInstanceId = 'EI-' || clipId
  summary~addEvent(pairEvent)

  return summary

makeOddSummary: procedure
  use arg clipId
  summary = makeSummaryWithTracks(clipId, 'T5', 'T6')
  summary~events[2]~zoneId = 'Z99'
  return summary

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
  say '  actual:' actual
  exit 1

::requires 'CameraCore.cls'
