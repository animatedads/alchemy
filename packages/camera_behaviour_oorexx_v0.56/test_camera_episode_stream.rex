/* Episode-aware binary stream compression tests for CameraCore.cls */

say 'CAMERA EPISODE STREAM SMOKE START'

camera = .CameraModel~new('CAMEPSTREAM', 640, 360)
sequenceKey = .CameraConstant~EVENT_APPROACH || ',' || .CameraConstant~EVENT_CLOSE || ',' || .CameraConstant~EVENT_SEPARATE
learnedEpisode = camera~episodeModel~learnSequence(sequenceKey)
learnedEpisode = camera~episodeModel~learnSequence(sequenceKey)
call assertEqual 'episode id', 'EP1', learnedEpisode~id
call assertTrue 'episode known', learnedEpisode~sampleCount >= 2

events = .array~new
firstEvent = .CameraEvent~new('E1', .CameraConstant~EVENT_APPROACH, 900, 'T1', 'T2', 45, 'pair-convergence')
firstEvent~episodeId = learnedEpisode~id
firstEvent~routeId = 'R7'
firstEvent~zoneId = 'Z3'
events~append(firstEvent)
secondEvent = .CameraEvent~new('E2', .CameraConstant~EVENT_CLOSE, 900, 'T1', 'T2', 35, 'pair-close')
secondEvent~episodeId = learnedEpisode~id
secondEvent~routeId = 'R7'
secondEvent~zoneId = 'Z6'
events~append(secondEvent)
thirdEvent = .CameraEvent~new('E3', .CameraConstant~EVENT_SEPARATE, 904, 'T1', 'T2', 90, 'pair-divergence')
thirdEvent~episodeId = learnedEpisode~id
thirdEvent~routeId = 'R7'
thirdEvent~zoneId = 'Z8'
events~append(thirdEvent)

rawDictionary = .CameraTokenDictionary~new
rawStream = .CameraEventStream~new(rawDictionary)
rawStream~appendEvents(events)
rawBytes = rawStream~byteCount

compressedStream = .CameraEventStream~new(camera~tokenDictionary, camera~episodeModel)
compressedStream~appendEventsCompressed(events)
compressedBytes = compressedStream~byteCount
call assertTrue 'episode stream smaller than literal stream', compressedBytes < rawBytes
call assertEqual 'compressed header', 'CBT2', compressedStream~encodedBytes~substr(1, 4)
call assertTrue 'episode token allocated', camera~tokenDictionary~tokenFor('EPISODE:EP1') > 0

decoded = compressedStream~decode
call assertEqual 'expanded event count', 3, decoded~items
call assertEvent 'expanded approach', events[1], decoded[1]
call assertEvent 'expanded close', events[2], decoded[2]
call assertEvent 'expanded separate', events[3], decoded[3]

/* A malformed/noncontiguous episode annotation must fall back to literal records. */
malformed = .array~new
malformedOne = .CameraEvent~new('M1', .CameraConstant~EVENT_APPROACH, 1000, 'T3', 'T4', 0, '')
malformedOne~episodeId = 'EP1'
malformed~append(malformedOne)
malformedTwo = .CameraEvent~new('M2', .CameraConstant~EVENT_SEPARATE, 1001, 'T3', 'T4', 0, '')
malformedTwo~episodeId = 'EP1'
malformed~append(malformedTwo)
malformedStream = .CameraEventStream~new(camera~tokenDictionary, camera~episodeModel)
malformedStream~appendEventsCompressed(malformed)
malformedDecoded = malformedStream~decode
call assertEqual 'malformed sequence remains two literal events', 2, malformedDecoded~items
call assertEqual 'malformed first type intact', .CameraConstant~EVENT_APPROACH, malformedDecoded[1]~eventType
call assertEqual 'malformed second type intact', .CameraConstant~EVENT_SEPARATE, malformedDecoded[2]~eventType

/* Persistence must retain both the episode grammar and its compact token identity. */
snapshotPath = '/tmp/camera_v014_episode.snapshot'
compressedOnDisk = compressedStream~encodedBytes
episodeTokenBefore = camera~tokenDictionary~tokenFor('EPISODE:EP1')
saved = .CameraModelPersistence~save(camera, snapshotPath)
call assertEqual 'snapshot saved', 1, saved
restored = .CameraModelPersistence~load(snapshotPath)
call assertTrue 'restored camera', restored \== .nil
episodeTokenAfter = restored~tokenDictionary~tokenFor('EPISODE:EP1')
call assertEqual 'episode token identity persisted', episodeTokenBefore, episodeTokenAfter
restoredEpisode = restored~episodeModel~episodeForId('EP1')
call assertTrue 'episode grammar persisted', restoredEpisode \== .nil
restoredStream = .CameraEventStream~new(restored~tokenDictionary, restored~episodeModel)
restoredDecoded = restoredStream~decode(compressedOnDisk)
call assertEqual 'restored camera expands old compressed stream', 3, restoredDecoded~items
call assertEvent 'restored close event exact', events[2], restoredDecoded[2]
call sysfiledelete snapshotPath

say '  literal bytes:   ' rawBytes
say '  episode bytes:   ' compressedBytes
say '  saved bytes:     ' rawBytes - compressedBytes
say 'CAMERA EPISODE STREAM SMOKE: OK'
exit 0

assertEvent: procedure
  use arg label, expected, actual
  if expected~eventType \= actual~eventType then do
    say 'ASSERT FAILED:' label 'event type'; exit 1
  end
  if expected~timestamp \= actual~timestamp then do
    say 'ASSERT FAILED:' label 'timestamp'; exit 1
  end
  if expected~trackAId \= actual~trackAId then do
    say 'ASSERT FAILED:' label 'track A'; exit 1
  end
  if expected~trackBId \= actual~trackBId then do
    say 'ASSERT FAILED:' label 'track B'; exit 1
  end
  if expected~routeId \= actual~routeId then do
    say 'ASSERT FAILED:' label 'route'; exit 1
  end
  if expected~zoneId \= actual~zoneId then do
    say 'ASSERT FAILED:' label 'zone'; exit 1
  end
  return .true

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
