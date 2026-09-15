/* Interaction episode grammar tests for CameraCore.cls */

say 'CAMERA EPISODE SMOKE START'

/* Direct model: an unknown sequence remains literal; repeated sequence earns a token. */
episodeModel = .CameraEpisodeModel~new
sequenceKey = .CameraConstant~EVENT_APPROACH || ',' || .CameraConstant~EVENT_CLOSE || ',' || .CameraConstant~EVENT_SEPARATE
literalBits = 24
firstEncoding = episodeModel~encodeSequence(sequenceKey, literalBits)
call assertEqual 'first sequence new', .CameraConstant~EPISODE_NEW, firstEncoding~state
call assertNear 'first sequence literal cost', literalBits, firstEncoding~encodedBits, 0.0001

dropValue = episodeModel~learnSequence(sequenceKey)
secondEncoding = episodeModel~encodeSequence(sequenceKey, literalBits)
call assertEqual 'one sample still literal', .CameraConstant~EPISODE_NEW, secondEncoding~state

dropValue = episodeModel~learnSequence(sequenceKey)
thirdEncoding = episodeModel~encodeSequence(sequenceKey, literalBits)
call assertEqual 'repeated sequence known', .CameraConstant~EPISODE_KNOWN, thirdEncoding~state
call assertTrue 'known episode cheaper', thirdEncoding~encodedBits < thirdEncoding~literalBits

/* Different ordering is not silently folded into the learned episode. */
oddSequence = .CameraConstant~EVENT_CLOSE || ',' || .CameraConstant~EVENT_APPROACH || ',' || .CameraConstant~EVENT_SEPARATE
oddEncoding = episodeModel~encodeSequence(oddSequence, literalBits)
call assertEqual 'unseen ordering remains new', .CameraConstant~EPISODE_NEW, oddEncoding~state

/* End-to-end: repeated pair interactions learn one episode grammar. */
camera = .CameraModel~new('CAMEP', 640, 360)
camera~behaviour~addWindow(.CameraBehaviourWindow~new(15 * 60, 60 * 60))
scene = camera~rootRegion
call feedPair camera, scene, 900, 100, 300
call feedPair camera, scene, 901, 140, 260
call feedPair camera, scene, 902, 180, 220
call feedPair camera, scene, 903, 140, 260
call feedPair camera, scene, 904, 100, 300
call expireTracks camera, 905
call assertEqual 'first pair episode learned', 1, camera~episodeModel~episodeCount

/* Second interaction with the same grammar should reuse EP1. */
call feedPair camera, scene, 1000, 100, 300
call feedPair camera, scene, 1001, 140, 260
call feedPair camera, scene, 1002, 180, 220
call feedPair camera, scene, 1003, 140, 260
call feedPair camera, scene, 1004, 100, 300
call expireTracks camera, 1005
call assertEqual 'same grammar stays one episode', 1, camera~episodeModel~episodeCount
learned = camera~episodeModel~episodeForSequence(sequenceKey)
call assertTrue 'episode has repeated support', learned~sampleCount >= 2

pairEventCount = 0
do derivedEvent over camera~eventGrammar~events
  if derivedEvent~episodeId = 'EP1' then pairEventCount = pairEventCount + 1
end
call assertTrue 'underlying pair events retain episode annotation', pairEventCount >= 6

/* Persistence retains episode identity and support. */
path = 'camera_episode_test.model'
dropValue = .CameraModelPersistence~save(camera, path)
restored = .CameraModelPersistence~load(path)
restoredEpisode = restored~episodeModel~episodeForSequence(sequenceKey)
call assertTrue 'episode restored', restoredEpisode \== .nil
call assertEqual 'episode id preserved', 'EP1', restoredEpisode~id
call assertEqual 'episode support preserved', learned~sampleCount, restoredEpisode~sampleCount
call sysfiledelete path

say 'CAMERA EPISODE SMOKE: OK'
exit 0

feedPair: procedure
  use arg cameraObject, parentRegion, secondOfDay, xA, xB
  observations = .array~new
  observations~append(.CameraObservation~new(secondOfDay, .CameraBox~new('EA' || secondOfDay, xA, 150, 20, 40, parentRegion), 0.04, 0.50))
  observations~append(.CameraObservation~new(secondOfDay, .CameraBox~new('EB' || secondOfDay, xB, 150, 20, 40, parentRegion), 0.04, 0.50))
  frameOutcome = cameraObject~observeFrame(secondOfDay, observations)
  return

expireTracks: procedure
  use arg cameraObject, firstEmptySecond
  emptyObservations = .array~new
  frameOutcome = cameraObject~observeFrame(firstEmptySecond, emptyObservations)
  frameOutcome = cameraObject~observeFrame(firstEmptySecond + 1, emptyObservations)
  frameOutcome = cameraObject~observeFrame(firstEmptySecond + 2, emptyObservations)
  return

assertEqual: procedure
  use arg label, expected, actual
  if expected == actual then return .true
  say 'ASSERT FAILED:' label
  say '  expected:' expected
  say '  actual:  ' actual
  exit 1

assertNear: procedure
  use arg label, expected, actual, tolerance
  if abs(expected - actual) <= tolerance then return .true
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
