/* Independent channel objects. One channel serializes its own calls; separate
 * channel objects execute concurrently through Object~START / Message objects.
 */

::class SpeechTTSChannel public
::method init
  expose channelId provider sink state
  use strict arg channelId, provider, sink = .nil
  if channelId == .nil then raise syntax 88.900 array('channelId required')
  if channelId = '' then raise syntax 88.900 array('channelId required')
  if provider == .nil then raise syntax 88.900 array('TTS provider required')
  if sink == .nil then sink = .nil
  state = 'IDLE'
::attribute channelId get
::attribute state get
::method providerName
  expose provider
  return provider~name
::method synthesize
  expose channelId provider sink state
  use arg request
  state = 'SYNTHESIZING'
  signal on syntax name failed
  signal on error name failed
  signal on failure name failed
  answer = provider~synthesize(request)
  if sink \= .nil then sink~putAudio(channelId, answer~artifact)
  state = 'IDLE'
  return answer
failed:
  say 'Speech channel failure' rc sigl condition('C') condition('D')
  state = 'FAILED'
  raise propagate
::method beginSynthesis
  expose channelId provider state
  use arg request
  if state \= 'IDLE' then raise syntax 88.900 array('TTS channel is busy: ' || channelId)
  state = 'STREAMING'
  signal on syntax name streamFailed
  signal on error name streamFailed
  signal on failure name streamFailed
  providerSession = provider~beginSynthesis(request)
  return .SpeechTTSStream~new(provider, providerSession, channelId, self)
streamFailed:
  say 'Speech stream start failure' rc sigl condition('C') condition('D')
  state = 'FAILED'
  raise propagate
::method streamFinished
  expose state
  use arg providerSession
  if state = 'STREAMING' then state = 'IDLE'
  return .true
::method beginSynthesisAsync unguarded
  use arg request
  return self~start('BEGINSYNTHESIS', request)

::method synthesizeAsync unguarded
  use arg request
  return self~start('SYNTHESIZE', request)

::class SpeechTTSStream public
::method init
  expose provider providerSession channelId owner state
  use strict arg provider, providerSession, channelId, owner = .nil
  if provider == .nil then raise syntax 88.900 array('stream provider required')
  if providerSession == .nil then raise syntax 88.900 array('provider session required')
  if providerSession = '' then raise syntax 88.900 array('provider session required')
  state = 'OPEN'
::attribute channelId get
::attribute state get
::method nextChunk
  expose provider providerSession state owner
  use strict arg timeoutMs = 1000
  if state \= 'OPEN' then return .nil
  chunk = provider~nextSynthesisChunk(providerSession, timeoutMs)
  if chunk == .nil then return .nil
  if chunk~isEnd then do
    state = 'ENDED'
    if owner \= .nil then owner~streamFinished(providerSession)
  end
  return chunk
::method releaseChunk
  expose provider
  use arg chunk
  if chunk == .nil then return .false
  if \chunk~isData then return .false
  return provider~releaseSynthesisChunk(chunk~ref)
::method cancel
  expose provider providerSession state owner
  if state \= 'OPEN' then return .false
  ok = provider~cancelSynthesis(providerSession)
  state = 'CANCELLED'
  if owner \= .nil then owner~streamFinished(providerSession)
  return ok

::class SpeechSTTChannel public
::method init
  expose channelId provider state
  use arg channelId, provider
  if channelId == .nil then raise syntax 88.900 array('channelId required')
  if channelId = '' then raise syntax 88.900 array('channelId required')
  if provider == .nil then raise syntax 88.900 array('STT provider required')
  state = 'IDLE'
::attribute channelId get
::attribute state get
::method providerName
  expose provider
  return provider~name
::method recognize
  expose provider state
  use arg request
  state = 'RECOGNIZING'
  signal on syntax name failed
  signal on error name failed
  signal on failure name failed
  answer = provider~recognize(request)
  state = 'IDLE'
  return answer
failed:
  say 'Speech channel failure' rc sigl condition('C') condition('D')
  state = 'FAILED'
  raise propagate
::method recognizeAsync unguarded
  use arg request
  return self~start('RECOGNIZE', request)
::method beginRecognition
  expose channelId provider state
  use strict arg audioFormat = .nil, language = '', options = .nil
  if state \= 'IDLE' then raise syntax 88.900 array('STT channel is busy: ' || channelId)
  if audioFormat == .nil then audioFormat = .SpeechAudioProfiles~telephonyWideband
  if language == .nil then language = ''
  if options == .nil then options = .Directory~new
  state = 'STREAMING'
  signal on syntax name streamFailed
  signal on error name streamFailed
  signal on failure name streamFailed
  providerSession = provider~beginRecognition(audioFormat, language, options)
  return .SpeechSTTStream~new(provider, providerSession, channelId, self, audioFormat, language)
streamFailed:
  say 'Speech stream start failure' rc sigl condition('C') condition('D')
  state = 'FAILED'
  raise propagate
::method streamFinished
  expose state
  use arg providerSession
  if state = 'STREAMING' then state = 'IDLE'
  return .true
::method beginRecognitionAsync unguarded
  use arg audioFormat, language, options
  return self~start('BEGINRECOGNITION', audioFormat, language, options)

::class SpeechSTTStream public
::method init
  expose provider providerSession channelId owner state audioFormat language finals
  use strict arg provider, providerSession, channelId, owner = .nil, audioFormat = .nil, language = ''
  if provider == .nil then raise syntax 88.900 array('STT stream provider required')
  if providerSession == .nil then raise syntax 88.900 array('STT provider session required')
  if providerSession = '' then raise syntax 88.900 array('STT provider session required')
  if audioFormat == .nil then audioFormat = .SpeechAudioProfiles~telephonyWideband
  if language == .nil then language = ''
  finals = .Array~new
  state = 'OPEN'
::attribute channelId get
::attribute state get
::attribute audioFormat get
::attribute language get
::method pushChunk
  expose provider providerSession state audioFormat
  use strict arg chunk
  if state \= 'OPEN' then return .false
  if chunk == .nil then return .false
  if \chunk~isData then return .false
  supplied = chunk~audioFormat
  if supplied~sampleRate \= audioFormat~sampleRate then raise syntax 88.900 array('STT chunk sample rate mismatch')
  if supplied~channels \= audioFormat~channels then raise syntax 88.900 array('STT chunk channel mismatch')
  if translate(supplied~sampleFormat) \= translate(audioFormat~sampleFormat) then raise syntax 88.900 array('STT chunk sample format mismatch')
  return provider~pushRecognitionChunk(providerSession, chunk~ref, chunk~byteCount)
::method endInput
  expose provider providerSession state
  if state \= 'OPEN' then return .false
  ok = provider~endRecognitionInput(providerSession)
  if ok then state = 'DRAINING'
  return ok
::method nextEvent
  expose provider providerSession state owner finals
  use strict arg timeoutMs = 1000
  if state = 'CANCELLED' then return .nil
  if state = 'ENDED' then return .nil
  event = provider~nextRecognitionEvent(providerSession, timeoutMs)
  if event == .nil then return .nil
  if event~isFinal then finals~append(event~text)
  if event~isEnd then do
    state = 'ENDED'
    if owner \= .nil then owner~streamFinished(providerSession)
  end
  return event
::method finalResult
  expose finals provider language
  text = ''
  do i = 1 to finals~items
    part = strip(finals[i])
    if part = '' then iterate
    if text = '' then text = part
    else text = text || ' ' || part
  end
  return .SpeechSTTResult~new(text, provider~name, language, -1)
::method cancel
  expose provider providerSession state owner
  if state = 'CANCELLED' then return .false
  if state = 'ENDED' then return .false
  ok = provider~cancelRecognition(providerSession)
  state = 'CANCELLED'
  if owner \= .nil then owner~streamFinished(providerSession)
  return ok

::class SpeechRuntime public
::method init
  expose channels
  channels = .Directory~new
::method addChannel
  expose channels
  use arg channel
  if channel == .nil then return .false
  id = channel~channelId
  if channels~hasIndex(id) then raise syntax 88.900 array('duplicate speech channel: ' || id)
  channels[id] = channel
  return .true
::method channel
  expose channels
  use arg id
  return channels[id]
::method channelIds
  expose channels
  return channels~allIndexes~makeArray
::method count
  expose channels
  return channels~items

::requires 'SpeechCore.cls'

/* SST is retained as a spelling alias for callers that use speech-to-text as
 * SST. The canonical semantic name remains STT. */
::class SpeechSSTChannel public subclass SpeechSTTChannel
