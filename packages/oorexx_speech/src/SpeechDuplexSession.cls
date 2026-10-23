/* SpeechDuplexSession.cls
 * Full-duplex speech orchestration over provider-neutral TTS/STT streams.
 *
 * This is deliberately not SIP/dialog authority and not a device backend.
 * A caller supplies channels plus PCM source/sink objects.  The session owns
 * only the lifetime and joining of the three speech activities:
 *   synthesis -> playback sink
 *   capture source -> recognition input
 *   recognition event drain -> transcript result
 */
::class SpeechDuplexBuild public
::constant VERSION '0.1-dev10'
::constant API 'speech.duplex/0.1'

::class SpeechDuplexOutcome public
::method init
  expose playbackChunks captureChunks recognitionResult recognitionEvents
  use strict arg playbackChunks=0, captureChunks=0, recognitionResult=.nil, recognitionEvents=.nil
  if recognitionEvents == .nil then recognitionEvents=.Array~new
::attribute playbackChunks get
::attribute captureChunks get
::attribute recognitionResult get
::attribute recognitionEvents get
::method finalText
  expose recognitionResult
  if recognitionResult == .nil then return ''
  return recognitionResult~text

::class SpeechDuplexSession public
::method init
  expose sessionId ttsChannel sttChannel source sink controller state synthesisStream recognitionStream playbackMessage captureMessage eventMessage outcome
  use strict arg sessionId, ttsChannel, sttChannel, source, sink, controller=.nil
  if sessionId == .nil then raise syntax 88.900 array('duplex sessionId required')
  if sessionId~string = '' then raise syntax 88.900 array('duplex sessionId required')
  if ttsChannel == .nil then raise syntax 88.900 array('duplex TTS channel required')
  if sttChannel == .nil then raise syntax 88.900 array('duplex STT channel required')
  if source == .nil then raise syntax 88.900 array('duplex PCM source required')
  if sink == .nil then raise syntax 88.900 array('duplex PCM sink required')
  if controller == .nil then controller=.SpeechLocalAudioController~new
  state='IDLE'
  synthesisStream=.nil; recognitionStream=.nil
  playbackMessage=.nil; captureMessage=.nil; eventMessage=.nil; outcome=.nil
::attribute sessionId get
::attribute state get
::attribute synthesisStream get
::attribute recognitionStream get

/* Start one full-duplex speech turn.  The STT stream is created first so
 * capture can begin immediately; TTS then starts independently. */
::method start
  expose ttsChannel sttChannel source sink controller state synthesisStream recognitionStream playbackMessage captureMessage eventMessage outcome
  use strict arg ttsRequest, recognitionFormat=.nil, recognitionLanguage='', recognitionOptions=.nil, captureBytes=640, playbackTimeoutMs=1000, eventTimeoutMs=1000
  if state \= 'IDLE' then raise syntax 88.900 array('duplex session is not idle')
  if ttsRequest == .nil then raise syntax 88.900 array('duplex TTS request required')
  if recognitionFormat == .nil then recognitionFormat=source~audioFormat
  if recognitionOptions == .nil then recognitionOptions=.Directory~new
  if recognitionLanguage == .nil then recognitionLanguage=''
  state='STARTING'
  signal on syntax name failed
  signal on error name failed
  signal on failure name failed
  recognitionStream=sttChannel~beginRecognition(recognitionFormat,recognitionLanguage,recognitionOptions)
  synthesisStream=ttsChannel~beginSynthesis(ttsRequest)
  playbackMessage=controller~playSynthesisAsync(synthesisStream,sink,playbackTimeoutMs)
  captureMessage=controller~feedRecognitionAsync(source,recognitionStream,captureBytes)
  eventMessage=.Message~new(self,'DRAINRECOGNITION','I',recognitionStream,eventTimeoutMs)
  eventMessage~start
  state='RUNNING'
  return self
failed:
  say 'Speech duplex start failure' rc sigl condition('C') condition('D')
  state='FAILED'
  self~cancel
  raise propagate

/* Drain recognition events on its own activity so Azure partial/final events
 * are consumed while microphone capture is still running.  No session object
 * state is mutated here; the returned Directory is joined by wait(). */
::method drainRecognition unguarded
  use strict arg stream, timeoutMs=1000
  events=.Array~new
  do forever
    if stream~state = 'CANCELLED' then leave
    if stream~state = 'ENDED' then leave
    event=stream~nextEvent(timeoutMs)
    if event == .nil then iterate
    events~append(event)
    if event~isEnd then leave
  end
  answer=.Directory~new
  answer['events']=events
  answer['result']=stream~finalResult
  return answer

::method wait
  expose state playbackMessage captureMessage eventMessage outcome
  if state = 'COMPLETE' then return outcome
  if state \= 'RUNNING' then raise syntax 88.900 array('duplex session is not running')
  signal on syntax name failed
  signal on error name failed
  signal on failure name failed
  playbackChunks=playbackMessage~result
  captureChunks=captureMessage~result
  recognition=eventMessage~result
  outcome=.SpeechDuplexOutcome~new(playbackChunks,captureChunks,recognition['result'],recognition['events'])
  state='COMPLETE'
  return outcome
failed:
  say 'Speech duplex wait failure' rc sigl condition('C') condition('D')
  state='FAILED'
  self~cancel
  raise propagate

::method cancel
  expose state synthesisStream recognitionStream source sink playbackMessage captureMessage eventMessage
  changed=.false
  if source \= .nil then source~close
  if sink \= .nil then sink~close
  if synthesisStream \= .nil then do
    if synthesisStream~state = 'OPEN' then do
      synthesisStream~cancel
      changed=.true
    end
  end
  if recognitionStream \= .nil then do
    if recognitionStream~state \= 'ENDED' then do
      if recognitionStream~state \= 'CANCELLED' then do
        recognitionStream~cancel
        changed=.true
      end
    end
  end
  stopped=self~stopWorker(playbackMessage)
  stopped=self~stopWorker(captureMessage)
  stopped=self~stopWorker(eventMessage)
  if state \= 'COMPLETE' then state='CANCELLED'
  return changed

::method stopWorker
  use strict arg message
  if message == .nil then return .false
  message~wait
  return .true

::requires 'SpeechChannels.cls'
::requires 'SpeechLocalAudio.cls'
