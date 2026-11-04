/* Speech dev13 RPC-Core binding regression. */
tracker=.SpeechTestConcurrencyTracker~new
runtime=.SpeechRuntime~new
tts=.SpeechTTSChannel~new('tts-rpc',.RpcTestTTSProvider~new,.nil)
stt=.SpeechSTTChannel~new('stt-rpc',.RpcTestSTTProvider~new)
runtime~addChannel(tts); runtime~addChannel(stt)
materials=.RpcTestMaterialAuthority~new
registry=.RpcServiceRegistry~new
service=.SpeechRpcInstaller~register(registry,runtime,materials)
registry~freeze
dispatcher=.RpcServiceDispatcher~new(registry)

r=dispatcher~invoke('speech','capabilities',.Directory~new,.nil)
call assertTrue r~ok,'capabilities dispatch'
call assertEq r~value['speechApi'],'oorexx.speech/0.1','speech API'
call assertFalse r~value['streamingJsonRpc'],'streaming must stay off JSON-RPC'
call assertEq r~value['channels']~items,2,'channel inventory'

r=dispatcher~invoke('speech','intentions',.Directory~new,.nil)
call assertTrue r~ok,'intentions dispatch'
call assertEq r~value['intentions']~items,3,'intentions count'

args=.Directory~new; args['channelId']='tts-rpc'; args['text']='remote hello'; args['language']='en-GB'
r=dispatcher~invoke('speech','synthesize',args,.nil)
call assertTrue r~ok,'TTS dispatch'
call assertEq r~value['material']['kind'],'storage-identity','published material kind'
call assertEq r~value['material']['reference'],'speech-output-1','published material reference'
call assertFalse r~value['material']~hasIndex('localPath'),'local path leaked over RPC'

args=.Directory~new; args['channelId']='stt-rpc'; args['materialReference']='speech-input-1'; args['language']='en-GB'
r=dispatcher~invoke('speech','recognize',args,.nil)
call assertTrue r~ok,'STT dispatch'
call assertEq r~value['text'],'recognized remote input','STT text'

noMaterial=.SpeechRpcService~new(runtime,.nil)
args=.Directory~new; args['channelId']='tts-rpc'; args['text']='must fail closed'
f=noMaterial~synthesize(args,.nil)
call assertTrue f~isA(.RpcServiceFault),'unpublished temp output must fail closed'
call assertEq f~code,'INVALID_ARGUMENT','unpublished temp fault'

published=.RpcTestPublishedRegistry~new
.SpeechRpcInstaller~publishHttps(published)
call assertEq published~count,4,'HTTPS publication count'
call assertFalse published~hasName('speech.stream'),'stream method must not be published'

say 'PASS Speech dev13 RPC control-plane service'
exit 0

assertTrue: procedure
  use strict arg truth,label
  if truth then return
  say 'FAIL' label
  exit 1
assertFalse: procedure
  use strict arg truth,label
  if \truth then return
  say 'FAIL' label
  exit 1
assertEq: procedure
  use strict arg actual,expected,label
  if actual=expected then return
  say 'FAIL' label 'expected='expected 'actual='actual
  exit 1

::class RpcTestTTSProvider subclass SpeechTTSProvider
::method name; return 'rpc-test-tts'
::method synthesize
  use strict arg request
  artifact=.SpeechAudioArtifact~new('/tmp/rpc-private.wav','audio/wav',.SpeechAudioProfiles~speechDefault,'rpc-test-tts')
  return .SpeechTTSResult~new(artifact,'rpc-test-tts')

::class RpcTestSTTProvider subclass SpeechSTTProvider
::method name; return 'rpc-test-stt'
::method recognize
  use strict arg request
  return .SpeechSTTResult~new('recognized remote input','rpc-test-stt',request~language,1)

::class RpcTestMaterialAuthority
::method init
  expose published
  published=0
::method publishSpeechArtifact
  expose published
  use strict arg artifact,context
  published+=1
  answer=.Directory~new
  answer['kind']='storage-identity'
  answer['reference']='speech-output-' || published
  return answer
::method resolveSpeechInput
  use strict arg reference,context
  if reference \= 'speech-input-1' then return .nil
  metadata=.Directory~new; metadata['storage_identity']=reference
  return .SpeechAudioArtifact~new('/tmp/materialised-input.wav','audio/wav',.SpeechAudioProfiles~speechDefault,'material-authority',metadata)

::class RpcTestPublishedRegistry
::method init
  expose names
  names=.Directory~new
::method registerOperation
  expose names
  use strict arg publicName,service,operation
  names[publicName]=service || ':' || operation
  return self
::method count
  expose names
  return names~items
::method hasName
  expose names
  use strict arg name
  return names~hasIndex(name)

::requires 'SpeechRpcService.cls'
::requires 'SpeechProviders.cls'
