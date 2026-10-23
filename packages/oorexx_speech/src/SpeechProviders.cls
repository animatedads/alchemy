/* Provider contracts and simple deterministic test providers. */

::class SpeechTTSProvider public
::method name
  return 'tts-provider'
::method synthesize
  use arg request
  raise syntax 93.914 array('SpeechTTSProvider.synthesize must be implemented')
::method beginSynthesis
  use arg request
  raise syntax 93.914 array('SpeechTTSProvider.beginSynthesis streaming not implemented')
::method nextSynthesisChunk
  use arg providerSession, timeoutMs
  raise syntax 93.914 array('SpeechTTSProvider.nextSynthesisChunk streaming not implemented')
::method cancelSynthesis
  use arg providerSession
  return .false
::method releaseSynthesisChunk
  use arg chunkRef
  return .false

::class SpeechSTTProvider public
::method name
  return 'stt-provider'
::method recognize
  use arg request
  raise syntax 93.914 array('SpeechSTTProvider.recognize must be implemented')
::method beginRecognition
  use arg audioFormat, language, options
  raise syntax 93.914 array('SpeechSTTProvider.beginRecognition streaming not implemented')
::method pushRecognitionChunk
  use arg providerSession, chunkRef, byteCount
  raise syntax 93.914 array('SpeechSTTProvider.pushRecognitionChunk streaming not implemented')
::method endRecognitionInput
  use arg providerSession
  return .false
::method nextRecognitionEvent
  use arg providerSession, timeoutMs
  raise syntax 93.914 array('SpeechSTTProvider.nextRecognitionEvent streaming not implemented')
::method cancelRecognition
  use arg providerSession
  return .false

::class SpeechTestConcurrencyTracker public
::method init
  expose active peak completed
  active = 0; peak = 0; completed = 0
::method enter
  expose active peak
  active += 1
  if active > peak then peak = active
  return active
::method leave
  expose active completed
  active -= 1; completed += 1
  return active
::method peak
  expose peak
  return peak
::method completed
  expose completed
  return completed

::class SpeechTestTTSProvider subclass SpeechTTSProvider public
::method init
  expose providerName tracker delay
  use strict arg providerName = 'test-tts', tracker = .nil, delay = 0.25
  if providerName == .nil then providerName = 'test-tts'
  if delay == .nil then delay = 0.25
::method name
  expose providerName
  return providerName
::method synthesize
  expose providerName tracker delay
  use arg request
  tracker~enter; call SysSleep delay
  format = .SpeechAudioFormat~new(16000, 1, 'S16LE', 'PCM')
  artifact = .SpeechAudioArtifact~new('memory:' || request~text, 'audio/test', format, providerName)
  tracker~leave
  return .SpeechTTSResult~new(artifact, providerName)

::class SpeechTestSTTProvider subclass SpeechSTTProvider public
::method init
  expose providerName tracker delay
  use strict arg providerName = 'test-stt', tracker = .nil, delay = 0.25
  if providerName == .nil then providerName = 'test-stt'
  if delay == .nil then delay = 0.25
::method name
  expose providerName
  return providerName
::method recognize
  expose providerName tracker delay
  use arg request
  tracker~enter; call SysSleep delay
  text = 'transcript:' || request~audio~ref
  tracker~leave
  return .SpeechSTTResult~new(text, providerName, request~language, 1)

::class SpeechTestStreamingTTSProvider subclass SpeechTTSProvider public
::method init
  expose providerName tracker delay sessions nextId
  use strict arg providerName = 'test-stream-tts', tracker = .nil, delay = 0.10
  if providerName == .nil then providerName = 'test-stream-tts'
  if delay == .nil then delay = 0.10
  sessions = .Directory~new; nextId = 0
::method name
  expose providerName
  return providerName
::method synthesize
  expose providerName
  use arg request
  format = .SpeechAudioFormat~new(24000, 1, 'S16LE', 'PCM')
  artifact = .SpeechAudioArtifact~new('memory:' || request~text, 'audio/wav', format, providerName)
  return .SpeechTTSResult~new(artifact, providerName)
::method beginSynthesis
  expose sessions nextId
  use arg request
  nextId += 1
  id = 'test-stream-' || nextId
  rec = .Directory~new
  rec['sequence'] = 0; rec['remaining'] = 3; rec['text'] = request~text; rec['cancelled'] = .false
  sessions[id] = rec
  return id
::method nextSynthesisChunk unguarded
  expose providerName tracker delay sessions
  use arg providerSession, timeoutMs
  if \sessions~hasIndex(providerSession) then raise syntax 88.900 array('unknown test stream session')
  rec = sessions[providerSession]
  if rec['cancelled'] then do
    sessions~remove(providerSession)
    return .SpeechAudioChunk~new('END', rec['sequence'], '', 0, .SpeechAudioFormat~new(24000,1,'S16LE','PCM'), providerName)
  end
  if rec['remaining'] <= 0 then do
    sessions~remove(providerSession)
    return .SpeechAudioChunk~new('END', rec['sequence'], '', 0, .SpeechAudioFormat~new(24000,1,'S16LE','PCM'), providerName)
  end
  if tracker \= .nil then tracker~enter
  call SysSleep delay
  rec['sequence'] = rec['sequence'] + 1
  rec['remaining'] = rec['remaining'] - 1
  seq = rec['sequence']
  if tracker \= .nil then tracker~leave
  return .SpeechAudioChunk~new('DATA', seq, 'memory:chunk:' || rec['text'] || ':' || seq, 9600, .SpeechAudioFormat~new(24000,1,'S16LE','PCM'), providerName)
::method cancelSynthesis
  expose sessions
  use arg providerSession
  if \sessions~hasIndex(providerSession) then return .false
  sessions[providerSession]['cancelled'] = .true
  return .true

::class SpeechTestStreamingSTTProvider subclass SpeechSTTProvider public
::method init
  expose providerName tracker delay sessions nextId
  use strict arg providerName = 'test-stream-stt', tracker = .nil, delay = 0.10
  if providerName == .nil then providerName = 'test-stream-stt'
  if delay == .nil then delay = 0.10
  sessions = .Directory~new; nextId = 0
::method name
  expose providerName
  return providerName
::method recognize
  expose providerName
  use arg request
  return .SpeechSTTResult~new('batch:' || request~audio~ref, providerName, request~language, 1)
::method beginRecognition
  expose sessions nextId
  use arg audioFormat, language, options
  nextId += 1
  id = 'test-stt-stream-' || nextId
  rec = .Directory~new
  rec['sequence'] = 0; rec['chunks'] = 0; rec['ended'] = .false; rec['cancelled'] = .false; rec['language'] = language
  sessions[id] = rec
  return id
::method pushRecognitionChunk
  expose sessions
  use arg providerSession, chunkRef, byteCount
  if \sessions~hasIndex(providerSession) then return .false
  rec = sessions[providerSession]
  if rec['ended'] then return .false
  if rec['cancelled'] then return .false
  rec['chunks'] = rec['chunks'] + 1
  return .true
::method endRecognitionInput
  expose sessions
  use arg providerSession
  if \sessions~hasIndex(providerSession) then return .false
  sessions[providerSession]['ended'] = .true
  return .true
::method nextRecognitionEvent unguarded
  expose sessions providerName tracker delay
  use arg providerSession, timeoutMs
  if \sessions~hasIndex(providerSession) then raise syntax 88.900 array('unknown test STT stream session')
  rec = sessions[providerSession]
  if rec['cancelled'] then do
    sessions~remove(providerSession)
    return .SpeechSTTEvent~new('END', rec['sequence'], '', providerName, rec['language'], -1)
  end
  if tracker \= .nil then tracker~enter
  call SysSleep delay
  if tracker \= .nil then tracker~leave
  rec['sequence'] = rec['sequence'] + 1
  seq = rec['sequence']
  if seq = 1 then return .SpeechSTTEvent~new('PARTIAL', seq, 'partial-' || rec['chunks'], providerName, rec['language'], -1)
  if seq = 2 then return .SpeechSTTEvent~new('FINAL', seq, 'final-' || rec['chunks'], providerName, rec['language'], 1)
  if rec['ended'] then do
    sessions~remove(providerSession)
    return .SpeechSTTEvent~new('END', seq, '', providerName, rec['language'], -1)
  end
  return .nil
::method cancelRecognition
  expose sessions
  use arg providerSession
  if \sessions~hasIndex(providerSession) then return .false
  sessions[providerSession]['cancelled'] = .true
  return .true

::requires 'SpeechCore.cls'
