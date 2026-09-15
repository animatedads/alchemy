say 'AUDIO RUNTIME REFERENCE WORKERS START'
port = value('AUDIO_REFERENCE_TEST_PORT',, 'ENVIRONMENT')
if port == '' then raise syntax 88.900 array('AUDIO_REFERENCE_TEST_PORT is required')

.RuntimeImplementationSwitch~reset
.AudioLibraryBuild~referenceSwitch = .nil
broker = .RuntimeImplementationBroker~new
provider = .RuntimeTcpJsonProvider~new('python.audio.reference', '127.0.0.1', port + 0, 2, 8388608, '')
broker~register(.AudioRuntimeOperation~MUSIC_FINGERPRINT, .RuntimeImplementationReference~new(provider, 100, .true, 1, 1))
broker~register(.AudioRuntimeOperation~SPEAKER_EMBEDDING, .RuntimeImplementationReference~new(provider, 100, .true, 1, 1))
broker~register(.AudioRuntimeOperation~SPEAKER_VERIFY, .RuntimeImplementationReference~new(provider, 100, .true, 1, 1))
broker~register(.AudioRuntimeOperation~MUSIC_IDENTIFY, .RuntimeImplementationReference~new(provider, 100, .true, 1, 1))
broker~register(.AudioRuntimeOperation~PITCH_EXTRACT, .RuntimeImplementationReference~new(provider, 100, .true, 1, 1))
.RuntimeImplementationSwitch~installBroker(broker)
.AudioLibraryBuild~referenceSwitch = .RuntimeImplementationSwitch

r = .directory~new
r['media_path'] = 'stub.wav'
a = .AudioRuntimeWorker~tryMusicFingerprint(r)
call assertTrue a~handled, 'fingerprint handled'
call assertEq 'AQABTESTFINGERPRINT', a~value['fingerprint'], 'fingerprint value'
call assertEq 'COMPLETED', broker~lastEvidence~outcomeCode, 'fingerprint evidence completed'
call assertEq 'python.audio.reference', broker~lastEvidence~providerId, 'provider identity'

r2 = .directory~new
r2['media_path'] = 'invalid-result'
a2 = .AudioRuntimeWorker~tryMusicFingerprint(r2)
call assertTrue \a2~handled, 'invalid provider value rejected'
call assertEq 'RESULT_VALIDATION_FAILED', a2~code, 'invalid result code'
call assertTrue a2~fallbackAllowed, 'invalid result permits local fallback'

se = .AudioRuntimeWorker~trySpeakerEmbedding(r)
call assertTrue se~handled, 'speaker embedding handled'
call assertEq 3, se~value['dimension'], 'speaker embedding dimension'

svr = .directory~new
svr['media_path_a'] = 'a.wav'; svr['media_path_b'] = 'b.wav'
sv = .AudioRuntimeWorker~trySpeakerVerify(svr)
call assertTrue sv~handled, 'speaker verify handled'

mi = .directory~new
mi['fingerprint'] = 'AQABTEST'; mi['duration_seconds'] = 11.6
m = .AudioRuntimeWorker~tryMusicIdentify(mi)
call assertTrue m~handled, 'music identify handled'
call assertEq 1, m~value['matches']~items, 'music identify match count'

p = .AudioRuntimeWorker~tryPitchExtract(r)
call assertTrue p~handled, 'pitch extract handled'
call assertEq 2, p~value['observations']~items, 'pitch observation count'

.AudioLibraryBuild~referenceSwitch = .nil
.RuntimeImplementationSwitch~reset
say 'AUDIO RUNTIME REFERENCE WORKERS: OK'
exit 0

::routine assertTrue
  use strict arg value, label
  if \value then raise syntax 88.900 array('FAILED ' || label)
  return
::routine assertEq
  use strict arg expected, actual, label
  if expected \= actual then raise syntax 88.900 array('FAILED ' || label || ' expected=' || expected || ' actual=' || actual)
  return

::requires '../AudioRuntimeWorkers.cls'
::requires 'RuntimeTcpJsonProvider.cls'
