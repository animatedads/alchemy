say 'AUDIO FOREIGNPYTHON ML START'
.RuntimeImplementationSwitch~reset
.AudioLibraryBuild~referenceSwitch = .nil

target = .AudioForeignPythonMLTarget~new('audio_ml_fixture')
call assertEq 'python.audio.foreign', target~providerId, 'provider id'
call assertEq 'ForeignPython', target~embeddingModel~runtime, 'generic ML model runtime'

broker = .RuntimeImplementationBroker~new
provider = .RuntimeObjectImplementationProvider~new(target~providerId, target)
broker~register(.AudioRuntimeOperation~SPEAKER_EMBEDDING, .RuntimeImplementationReference~new(provider, 100, .true, 1, 1))
broker~register(.AudioRuntimeOperation~SPEAKER_VERIFY, .RuntimeImplementationReference~new(provider, 100, .true, 1, 1))
.RuntimeImplementationSwitch~installBroker(broker)
.AudioLibraryBuild~referenceSwitch = .RuntimeImplementationSwitch

r = .Directory~new
r['media_path'] = 'fixture.wav'
r['model_source'] = 'fixture/ecapa'
r['model_revision'] = 'fixture-1'
a = .AudioRuntimeWorker~trySpeakerEmbedding(r)
call assertTrue a~handled, 'ForeignPython embedding handled'
call assertEq 3, a~value['dimension'], 'embedding dimension'
call assertEq 0.125, a~value['embedding'][1], 'embedding first value'
call assertEq 'ForeignPython', a~value['ml_runtime'], 'ML runtime evidence'
call assertEq 'gil-managed', a~value['ml_threading_mode'], 'GIL evidence'
call assertEq 'fixture-speechbrain', a~value['speechbrain_version'], 'library version evidence'
call assertEq 'python.audio.foreign', broker~lastEvidence~providerId, 'Runtime Reference provider evidence'

v = .Directory~new
v['media_path_a'] = 'a.wav'; v['media_path_b'] = 'b.wav'; v['threshold'] = 'PROVIDER_DEFAULT'
b = .AudioRuntimeWorker~trySpeakerVerify(v)
call assertTrue b~handled, 'ForeignPython verification handled'
call assertEq 0.8125, b~value['score'], 'verification score'
call assertTrue b~value['decision'], 'verification decision'
call assertEq 'MODEL_PROVIDER_SCORE', b~value['metric'], 'metric semantics preserved'

target~close
.AudioLibraryBuild~referenceSwitch = .nil
.RuntimeImplementationSwitch~reset
say 'AUDIO FOREIGNPYTHON ML: OK'
exit 0

::routine assertTrue
  use strict arg value,label
  if \value then raise syntax 88.900 array('FAILED ' || label)
::routine assertEq
  use strict arg expected,actual,label
  if expected \= actual then raise syntax 88.900 array('FAILED ' || label || ' expected=' || expected || ' actual=' || actual)

::requires '../AudioForeignPythonMLProvider.cls'
