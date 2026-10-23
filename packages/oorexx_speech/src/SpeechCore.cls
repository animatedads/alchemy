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
  use strict arg sampleRate = 16000, channels = 1, sampleFormat = 'S16LE', encoding = 'PCM'
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


::class SpeechAudioProfiles public
::method speechDefault class
  return .SpeechAudioFormat~new(16000, 1, 'S16LE', 'PCM')
::method azureTTS class
  return .SpeechAudioFormat~new(24000, 1, 'S16LE', 'PCM')
::method telephonyNarrowband class
  return .SpeechAudioFormat~new(8000, 1, 'S16LE', 'PCM')
::method telephonyWideband class
  return .SpeechAudioFormat~new(16000, 1, 'S16LE', 'PCM')
::method named class
  use strict arg profileName
  name = translate(profileName)
  select
    when name = '' then return self~speechDefault
    when name = 'DEFAULT' then return self~speechDefault
    when name = 'SPEECH-16K' then return self~telephonyWideband
    when name = 'TELEPHONY-8K' then return self~telephonyNarrowband
    when name = 'AZURE-TTS-24K' then return self~azureTTS
    otherwise raise syntax 88.900 array('unknown speech audio profile: ' || profileName)
  end

::class SpeechSTTEvent public
::method init
  expose kind sequence text provider language confidence metadata
  use strict arg kind, sequence = 0, text = '', provider = '', language = '', confidence = .nil, metadata = .nil
  kind = translate(kind)
  if kind \= 'PARTIAL' then do
    if kind \= 'FINAL' then do
      if kind \= 'END' then raise syntax 88.900 array('STT event kind must be PARTIAL, FINAL or END')
    end
  end
  if \datatype(sequence, 'W') then raise syntax 88.900 array('STT event sequence must be whole number')
  if sequence < 0 then raise syntax 88.900 array('STT event sequence must not be negative')
  if text == .nil then text = ''
  if provider == .nil then provider = ''
  if language == .nil then language = ''
  if confidence == .nil then confidence = -1
  if metadata == .nil then metadata = .Directory~new
::attribute kind get
::attribute sequence get
::attribute text get
::attribute provider get
::attribute language get
::attribute confidence get
::attribute metadata get
::method isPartial
  expose kind
  return kind = 'PARTIAL'
::method isFinal
  expose kind
  return kind = 'FINAL'
::method isEnd
  expose kind
  return kind = 'END'

::class SpeechAudioArtifact public
::method init
  expose ref mediaType audioFormat provider metadata
  use strict arg ref, mediaType = 'audio/wav', audioFormat = .nil, provider = '', metadata = .nil
  if ref == .nil then raise syntax 88.900 array('audio artifact ref required')
  if ref = '' then raise syntax 88.900 array('audio artifact ref required')
  if mediaType == .nil then mediaType = 'audio/wav'
  if audioFormat == .nil then audioFormat = .SpeechAudioFormat~new
  if provider == .nil then provider = ''
  if metadata == .nil then metadata = .Directory~new
::attribute ref get
::attribute mediaType get
::attribute audioFormat get
::attribute provider get
::attribute metadata get

::class SpeechTTSRequest public
::method init
  expose text voice language options
  use strict arg text, voice = '', language = '', options = .nil
  if text == .nil then raise syntax 88.900 array('TTS text required')
  if text = '' then raise syntax 88.900 array('TTS text required')
  if voice == .nil then voice = ''
  if language == .nil then language = ''
  if options == .nil then options = .Directory~new
::attribute text get
::attribute voice get
::attribute language get
::attribute options get
::method audioProfile
  expose options
  if options == .nil then return ''
  if options~hasIndex('audioProfile') then return options['audioProfile']
  return ''

::class SpeechSTTRequest public
::method init
  expose audio language options
  use strict arg audio, language = '', options = .nil
  if audio == .nil then raise syntax 88.900 array('STT audio required')
  if language == .nil then language = ''
  if options == .nil then options = .Directory~new
::attribute audio get
::attribute language get
::attribute options get

::class SpeechTTSResult public
::method init
  expose artifact provider metadata
  use strict arg artifact, provider = '', metadata = .nil
  if artifact == .nil then raise syntax 88.900 array('TTS artifact required')
  if provider == .nil then provider = ''
  if metadata == .nil then metadata = .Directory~new
::attribute artifact get
::attribute provider get
::attribute metadata get

::class SpeechSTTResult public
::method init
  expose text provider language confidence metadata
  use strict arg text = '', provider = '', language = '', confidence = .nil, metadata = .nil
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

/* Incremental TTS audio.  DATA chunks reference raw PCM material that can be
 * consumed immediately by a local/SIP audio controller.  END is an explicit
 * terminal marker; timeout/no-data is represented by .nil from nextChunk(). */
::class SpeechAudioChunk public
::method init
  expose kind sequence ref byteCount audioFormat provider metadata
  use strict arg kind, sequence = 0, ref = '', byteCount = 0, audioFormat = .nil, provider = '', metadata = .nil
  kind = translate(kind)
  if kind \= 'DATA' then do
    if kind \= 'END' then raise syntax 88.900 array('chunk kind must be DATA or END')
  end
  if \datatype(sequence, 'W') then raise syntax 88.900 array('chunk sequence must be whole number')
  if \datatype(byteCount, 'W') then raise syntax 88.900 array('chunk byteCount must be whole number')
  if sequence < 0 then raise syntax 88.900 array('chunk sequence must not be negative')
  if byteCount < 0 then raise syntax 88.900 array('chunk byteCount must not be negative')
  if kind = 'DATA' then do
    if ref == .nil then raise syntax 88.900 array('DATA chunk ref required')
    if ref = '' then raise syntax 88.900 array('DATA chunk ref required')
  end
  if ref == .nil then ref = ''
  if audioFormat == .nil then audioFormat = .SpeechAudioFormat~new(24000, 1, 'S16LE', 'PCM')
  if provider == .nil then provider = ''
  if metadata == .nil then metadata = .Directory~new
::attribute kind get
::attribute sequence get
::attribute ref get
::attribute byteCount get
::attribute audioFormat get
::attribute provider get
::attribute metadata get
::method isData
  expose kind
  return kind = 'DATA'
::method isEnd
  expose kind
  return kind = 'END'
