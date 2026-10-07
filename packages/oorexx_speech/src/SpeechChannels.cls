/* Independent channel objects. One channel serializes its own calls; separate
 * channel objects execute concurrently through Object~START / Message objects.
 */

::class SpeechTTSChannel public
::method init
  expose channelId provider sink state
  use arg channelId, provider, sink
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
  state = 'FAILED'
  raise propagate
::method synthesizeAsync unguarded
  use arg request
  return self~start('SYNTHESIZE', request)

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
  state = 'FAILED'
  raise propagate
::method recognizeAsync unguarded
  use arg request
  return self~start('RECOGNIZE', request)

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
