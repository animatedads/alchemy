/* SpeechRpcService.cls
 * Optional RPC-Core binding for ooRexx Speech.
 *
 * Speech owns speech semantics. RPC Core owns object/method dispatch; the
 * HTTPS JSON-RPC gateway owns HTTP/TLS publication and platform authorization.
 * This adapter exposes unary control-plane operations only. Streaming PCM is
 * intentionally not published through ordinary JSON-RPC.
 */

::class SpeechRpcBuild public
::constant VERSION '0.1-dev13'
::constant API 'speech.rpc/0.1'
::constant SERVICE 'speech'

::class SpeechRpcService public
::method init
  expose runtime intentions materialAuthority
  use strict arg runtime, materialAuthority=.nil
  if runtime == .nil then raise syntax 88.900 array('SpeechRuntime is required')
  intentions=.SpeechIntentionProvider~new

::method capabilities
  expose runtime
  use strict arg arguments=.nil, context=.nil
  answer=.Directory~new
  answer['api']=.SpeechRpcBuild~API
  answer['speechApi']=.SpeechBuild~api
  answer['streamingJsonRpc']=.false
  answer['channels']=self~channelInventory
  profiles=.Array~new
  profiles~append('telephony-8k')
  profiles~append('speech-16k')
  profiles~append('azure-tts-24k')
  answer['audioProfiles']=profiles
  return answer

::method channelInventory
  expose runtime
  rows=.Array~new
  ids=runtime~channelIds
  do id over ids
    channel=runtime~channel(id)
    if channel == .nil then iterate
    row=.Directory~new
    row['channelId']=channel~channelId
    row['state']=channel~state
    row['provider']=channel~providerName
    if channel~isA(.SpeechTTSChannel) then row['kind']='TTS'
    else if channel~isA(.SpeechSTTChannel) then row['kind']='STT'
    else row['kind']='OTHER'
    rows~append(row)
  end
  return rows

::method discoverIntentions
  expose runtime intentions
  use strict arg arguments=.nil, context=.nil
  snapshot=intentions~discover(runtime)
  rows=.Array~new
  do candidate over snapshot~intentions
    row=.Directory~new
    row['id']=candidate~intentionId
    row['meaning']=candidate~meaning
    row['featureKind']=candidate~featureKind
    row['state']=candidate~state
    row['reason']=candidate~reason
    target=candidate~target
    if target \== .nil then do
      if target~hasMethod('CHANNELID') then row['channelId']=target~channelId
    end
    rows~append(row)
  end
  answer=.Directory~new
  answer['generation']=snapshot~generation
  answer['intentions']=rows
  return answer

::method synthesize
  expose runtime materialAuthority
  use strict arg arguments, context=.nil
  check=self~requireArguments(arguments)
  if check~isA(.RpcServiceFault) then return check
  channelId=self~requiredString(arguments,'channelId')
  if channelId~isA(.RpcServiceFault) then return channelId
  text=self~requiredString(arguments,'text')
  if text~isA(.RpcServiceFault) then return text
  channel=runtime~channel(channelId)
  if channel == .nil then return .RpcServiceFault~new('NOT_FOUND','Speech channel not found')
  if \channel~isA(.SpeechTTSChannel) then return .RpcServiceFault~new('INVALID_ARGUMENT','Channel is not TTS')
  if channel~state \= 'IDLE' then return .RpcServiceFault~new('INVALID_ARGUMENT','Speech channel is busy')
  voice=self~optionalString(arguments,'voice','')
  if voice~isA(.RpcServiceFault) then return voice
  language=self~optionalString(arguments,'language','')
  if language~isA(.RpcServiceFault) then return language
  options=.Directory~new
  if arguments~hasIndex('audioProfile') then do
    profile=self~optionalString(arguments,'audioProfile','')
    if profile~isA(.RpcServiceFault) then return profile
    if profile \= '' then options['audioProfile']=profile
  end
  ttsResult=channel~synthesize(.SpeechTTSRequest~new(text,voice,language,options))
  published=self~publishArtifact(ttsResult~artifact,context)
  if published~isA(.RpcServiceFault) then return published
  answer=.Directory~new
  answer['provider']=ttsResult~provider
  answer['material']=published
  answer['format']=self~formatDescriptor(ttsResult~artifact~audioFormat)
  answer['mediaType']=ttsResult~artifact~mediaType
  return answer

::method recognize
  expose runtime materialAuthority
  use strict arg arguments, context=.nil
  check=self~requireArguments(arguments)
  if check~isA(.RpcServiceFault) then return check
  channelId=self~requiredString(arguments,'channelId')
  if channelId~isA(.RpcServiceFault) then return channelId
  reference=self~requiredString(arguments,'materialReference')
  if reference~isA(.RpcServiceFault) then return reference
  channel=runtime~channel(channelId)
  if channel == .nil then return .RpcServiceFault~new('NOT_FOUND','Speech channel not found')
  if \channel~isA(.SpeechSTTChannel) then return .RpcServiceFault~new('INVALID_ARGUMENT','Channel is not STT')
  if channel~state \= 'IDLE' then return .RpcServiceFault~new('INVALID_ARGUMENT','Speech channel is busy')
  if materialAuthority == .nil then return .RpcServiceFault~new('INVALID_ARGUMENT','Speech material authority is not configured')
  if \materialAuthority~hasMethod('RESOLVESPEECHINPUT') then return .RpcServiceFault~new('INVALID_ARGUMENT','Speech material resolver unavailable')
  artifact=materialAuthority~resolveSpeechInput(reference,context)
  if artifact == .nil then return .RpcServiceFault~new('NOT_FOUND','Speech input material not found')
  language=self~optionalString(arguments,'language','')
  if language~isA(.RpcServiceFault) then return language
  sttResult=channel~recognize(.SpeechSTTRequest~new(artifact,language))
  answer=.Directory~new
  answer['text']=sttResult~text
  answer['provider']=sttResult~provider
  answer['language']=sttResult~language
  answer['confidence']=sttResult~confidence
  return answer

::method publishArtifact
  expose materialAuthority
  use strict arg artifact, context
  metadata=artifact~metadata
  if metadata \== .nil then do
    if metadata~hasIndex('external_ref') then return self~materialDescriptor('external',metadata['external_ref'])
    if metadata~hasIndex('storage_identity') then return self~materialDescriptor('storage-identity',metadata['storage_identity'])
  end
  if materialAuthority == .nil then return .RpcServiceFault~new('INVALID_ARGUMENT','TTS output has no durable remote material reference')
  if \materialAuthority~hasMethod('PUBLISHSPEECHARTIFACT') then return .RpcServiceFault~new('INVALID_ARGUMENT','Speech material publisher unavailable')
  published=materialAuthority~publishSpeechArtifact(artifact,context)
  if published == .nil then return .RpcServiceFault~new('INTERNAL','Speech output material publication failed')
  return published

::method materialDescriptor
  use strict arg kind, reference
  answer=.Directory~new
  answer['kind']=kind
  answer['reference']=reference
  return answer

::method formatDescriptor
  use strict arg format
  answer=.Directory~new
  answer['sampleRate']=format~sampleRate
  answer['channels']=format~channels
  answer['sampleFormat']=format~sampleFormat
  answer['encoding']=format~encoding
  return answer

::method requireArguments
  use strict arg arguments
  if arguments == .nil then return .RpcServiceFault~new('INVALID_ARGUMENT','Arguments are required')
  if arguments~isA(.Directory) then return .true
  if arguments~isA(.Table) then return .true
  return .RpcServiceFault~new('INVALID_ARGUMENT','Arguments must be a Directory or Table')

::method requiredString
  use strict arg arguments, name
  if \arguments~hasIndex(name) then return .RpcServiceFault~new('INVALID_ARGUMENT','Missing argument: ' || name)
  value=arguments[name]
  if \value~isA(.String) then return .RpcServiceFault~new('INVALID_ARGUMENT','Argument must be string: ' || name)
  if value == '' then return .RpcServiceFault~new('INVALID_ARGUMENT','Argument must not be empty: ' || name)
  return value

::method optionalString
  use strict arg arguments, name, defaultValue=''
  if \arguments~hasIndex(name) then return defaultValue
  value=arguments[name]
  if \value~isA(.String) then return .RpcServiceFault~new('INVALID_ARGUMENT','Argument must be string: ' || name)
  return value

::class SpeechRpcInstaller public
::method register class
  use strict arg serviceRegistry, runtime, materialAuthority=.nil
  service=.SpeechRpcService~new(runtime,materialAuthority)
  serviceRegistry~registerMethod(.SpeechRpcBuild~SERVICE,'capabilities',service,'capabilities')
  serviceRegistry~registerMethod(.SpeechRpcBuild~SERVICE,'intentions',service,'discoverIntentions')
  serviceRegistry~registerMethod(.SpeechRpcBuild~SERVICE,'synthesize',service,'synthesize')
  serviceRegistry~registerMethod(.SpeechRpcBuild~SERVICE,'recognize',service,'recognize')
  return service

::method publishHttps class
  use strict arg publishedRegistry
  publishedRegistry~registerOperation('speech.capabilities',.SpeechRpcBuild~SERVICE,'capabilities')
  publishedRegistry~registerOperation('speech.intentions',.SpeechRpcBuild~SERVICE,'intentions')
  publishedRegistry~registerOperation('speech.synthesize',.SpeechRpcBuild~SERVICE,'synthesize')
  publishedRegistry~registerOperation('speech.recognize',.SpeechRpcBuild~SERVICE,'recognize')
  return publishedRegistry

::requires 'SpeechIntentions.cls'
::requires 'RpcServiceCore.cls'
