/* Provider contracts and simple deterministic test providers. */

::class SpeechTTSProvider public
::method name
  return 'tts-provider'
::method synthesize
  use arg request
  raise syntax 93.914 array('SpeechTTSProvider.synthesize must be implemented')

::class SpeechSTTProvider public
::method name
  return 'stt-provider'
::method recognize
  use arg request
  raise syntax 93.914 array('SpeechSTTProvider.recognize must be implemented')

::class SpeechTestConcurrencyTracker public
::method init
  expose active peak completed
  active = 0
  peak = 0
  completed = 0
::method enter
  expose active peak
  active += 1
  if active > peak then peak = active
  return active
::method leave
  expose active completed
  active -= 1
  completed += 1
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
  use arg providerName, tracker, delay
  if providerName == .nil then providerName = 'test-tts'
  if delay == .nil then delay = 0.25
::method name
  expose providerName
  return providerName
::method synthesize
  expose providerName tracker delay
  use arg request
  tracker~enter
  call SysSleep delay
  format = .SpeechAudioFormat~new(16000, 1, 'S16LE', 'PCM')
  artifact = .SpeechAudioArtifact~new('memory:' || request~text, 'audio/test', format, providerName)
  tracker~leave
  return .SpeechTTSResult~new(artifact, providerName)

::class SpeechTestSTTProvider subclass SpeechSTTProvider public
::method init
  expose providerName tracker delay
  use arg providerName, tracker, delay
  if providerName == .nil then providerName = 'test-stt'
  if delay == .nil then delay = 0.25
::method name
  expose providerName
  return providerName
::method recognize
  expose providerName tracker delay
  use arg request
  tracker~enter
  call SysSleep delay
  text = 'transcript:' || request~audio~ref
  tracker~leave
  return .SpeechSTTResult~new(text, providerName, request~language, 1)

::requires 'SpeechCore.cls'
