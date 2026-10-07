/* ooRexx Speech core semantic objects. */

::class SpeechBuild public
::method api class
  return 'oorexx.speech/0.1'
::method ttsApi class
  return 'oorexx.speech.tts/0.1'
::method sttApi class
  return 'oorexx.speech.stt/0.1'
::method sstApi class
  return 'oorexx.speech.stt/0.1'

::class SpeechAudioFormat public
::method init
  expose sampleRate channels sampleFormat encoding
  use arg sampleRate, channels, sampleFormat, encoding
  if sampleRate == .nil then sampleRate = 16000
  if channels == .nil then channels = 1
  if sampleFormat == .nil then sampleFormat = 'S16LE'
  if encoding == .nil then encoding = 'PCM'
  if \datatype(sampleRate, 'W') then raise syntax 88.900 array('sampleRate must be whole number')
  if \datatype(channels, 'W') then raise syntax 88.900 array('channels must be whole number')
  if sampleRate < 1000 then raise syntax 88.900 array('sampleRate too small')
  if channels < 1 then raise syntax 88.900 array('channels must be positive')
::attribute sampleRate get
::attribute channels get
::attribute sampleFormat get
::attribute encoding get

::class SpeechAudioArtifact public
::method init
  expose ref mediaType audioFormat provider
  use arg ref, mediaType, audioFormat, provider
  if ref == .nil then raise syntax 88.900 array('audio artifact ref required')
  if ref = '' then raise syntax 88.900 array('audio artifact ref required')
  if mediaType == .nil then mediaType = 'audio/wav'
  if audioFormat == .nil then audioFormat = .SpeechAudioFormat~new
  if provider == .nil then provider = ''
::attribute ref get
::attribute mediaType get
::attribute audioFormat get
::attribute provider get

::class SpeechTTSRequest public
::method init
  expose text voice language options
  use arg text, voice, language, options
  if text == .nil then raise syntax 88.900 array('TTS text required')
  if text = '' then raise syntax 88.900 array('TTS text required')
  if voice == .nil then voice = ''
  if language == .nil then language = ''
  if options == .nil then options = .Directory~new
::attribute text get
::attribute voice get
::attribute language get
::attribute options get

::class SpeechSTTRequest public
::method init
  expose audio language options
  use arg audio, language, options
  if audio == .nil then raise syntax 88.900 array('STT audio required')
  if language == .nil then language = ''
  if options == .nil then options = .Directory~new
::attribute audio get
::attribute language get
::attribute options get

::class SpeechTTSResult public
::method init
  expose artifact provider metadata
  use arg artifact, provider, metadata
  if artifact == .nil then raise syntax 88.900 array('TTS artifact required')
  if provider == .nil then provider = ''
  if metadata == .nil then metadata = .Directory~new
::attribute artifact get
::attribute provider get
::attribute metadata get

::class SpeechSTTResult public
::method init
  expose text provider language confidence metadata
  use arg text, provider, language, confidence, metadata
  if text == .nil then text = ''
  if provider == .nil then provider = ''
  if language == .nil then language = ''
  if confidence == .nil then confidence = -1
  if metadata == .nil then metadata = .Directory~new
::attribute text get
::attribute provider get
::attribute language get
::attribute confidence get
::attribute metadata get

/* A controller may implement putAudio(channelId, artifact). */
::class SpeechAudioSink public
::method putAudio
  use arg channelId, artifact
  raise syntax 93.914 array('SpeechAudioSink.putAudio must be implemented')

/* A controller may expose an artifact/file/stream reference through nextAudio(). */
::class SpeechAudioSource public
::method nextAudio
  raise syntax 93.914 array('SpeechAudioSource.nextAudio must be implemented')
