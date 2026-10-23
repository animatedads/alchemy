/*
 * Python Macrospace adapter.
 *
 * This class deliberately accepts an already-resident projected Python object.
 * Macrospace / Alchemy Foreign Object remains authoritative for Python class
 * loading, identity, pin/call/release and revocation. Speech does not launch
 * Python processes and does not mutate global Python search paths.
 *
 * Scalar/file-artifact boundary for dev1:
 *   Python TTS: synthesize_to_file(text, voice, language) -> path string
 *   Python STT: transcribe_file(path, language) -> transcript string
 *
 * Batch calls retain the conservative file-artifact boundary.  dev6 adds an
 * incremental TTS descriptor seam: provider-generated raw PCM chunks remain
 * external artifacts while Macrospace carries only scalar session/chunk metadata.
 */

::class SpeechMacrospaceTTSProvider subclass SpeechTTSProvider public
::method init
  expose pythonObject providerName audioFormat mediaType streamFormats
  use strict arg pythonObject, providerName = 'macrospace-tts', audioFormat = .nil, mediaType = 'audio/wav'
  if pythonObject == .nil then raise syntax 88.900 array('resident Python object required')
  if providerName == .nil then providerName = 'macrospace-tts'
  if audioFormat == .nil then audioFormat = .SpeechAudioFormat~new(24000, 1, 'S16LE', 'PCM')
  if mediaType == .nil then mediaType = 'audio/wav'
  streamFormats = .Directory~new
::method name
  expose providerName
  return providerName
::method formatForProfile
  expose audioFormat
  use strict arg profile = ''
  profile = translate(profile)
  if profile = 'TELEPHONY-8K' then return .SpeechAudioProfiles~telephonyNarrowband
  if profile = 'SPEECH-16K' then return .SpeechAudioProfiles~telephonyWideband
  return audioFormat
::method synthesize
  expose pythonObject providerName mediaType
  use arg request
  profile = request~audioProfile
  path = pythonObject~synthesize_to_file(request~text, request~voice, request~language, profile)
  if path == .nil then raise syntax 88.900 array('Python TTS provider returned no artifact path')
  if path = '' then raise syntax 88.900 array('Python TTS provider returned no artifact path')
  artifact = .SpeechAudioArtifact~new(path, mediaType, self~formatForProfile(profile), providerName)
  return .SpeechTTSResult~new(artifact, providerName)
::method beginSynthesis
  expose pythonObject streamFormats
  use arg request
  profile = request~audioProfile
  session = pythonObject~begin_synthesis(request~text, request~voice, request~language, profile)
  streamFormats[session] = self~formatForProfile(profile)
  return session
::method nextSynthesisChunk unguarded
  expose pythonObject providerName streamFormats
  use arg providerSession, timeoutMs
  format = streamFormats[providerSession]
  if format == .nil then format = .SpeechAudioProfiles~azureTTS
  descriptor = pythonObject~next_synthesis_chunk(providerSession, timeoutMs)
  if descriptor == .nil then return .nil
  if descriptor = '' then return .nil
  parse var descriptor kind '|' seq '|' byteCount '|' ref
  kind = translate(kind)
  if kind = 'WAIT' then return .nil
  if kind = 'END' then do
    streamFormats~remove(providerSession)
    return .SpeechAudioChunk~new('END', seq, '', 0, format, providerName)
  end
  if kind \= 'DATA' then raise syntax 88.900 array('unknown Python TTS stream descriptor: ' || descriptor)
  return .SpeechAudioChunk~new('DATA', seq, ref, byteCount, format, providerName)
::method cancelSynthesis
  expose pythonObject streamFormats
  use arg providerSession
  answer = pythonObject~cancel_synthesis(providerSession)
  streamFormats~remove(providerSession)
  if translate(answer) = 'TRUE' then return .true
  if answer = 1 then return .true
  return .false
::method releaseSynthesisChunk
  expose pythonObject
  use arg chunkRef
  answer = pythonObject~release_synthesis_chunk(chunkRef)
  if translate(answer) = 'TRUE' then return .true
  if answer = 1 then return .true
  return .false

::class SpeechMacrospaceSTTProvider subclass SpeechSTTProvider public
::method init
  expose pythonObject providerName
  use strict arg pythonObject, providerName = 'macrospace-stt'
  if pythonObject == .nil then raise syntax 88.900 array('resident Python object required')
  if providerName == .nil then providerName = 'macrospace-stt'
::method name
  expose providerName
  return providerName
::method recognize
  expose pythonObject providerName
  use arg request
  path = request~audio~ref
  text = pythonObject~transcribe_file(path, request~language)
  if text == .nil then text = ''
  return .SpeechSTTResult~new(text, providerName, request~language, -1)
::method beginRecognition
  expose pythonObject
  use arg audioFormat, language, options
  return pythonObject~begin_recognition(language, audioFormat~sampleRate, 16, audioFormat~channels)
::method pushRecognitionChunk
  expose pythonObject
  use arg providerSession, chunkRef, byteCount
  answer = pythonObject~push_recognition_chunk(providerSession, chunkRef)
  if translate(answer) = 'TRUE' then return .true
  if answer = 1 then return .true
  return .false
::method endRecognitionInput
  expose pythonObject
  use arg providerSession
  answer = pythonObject~end_recognition_input(providerSession)
  if translate(answer) = 'TRUE' then return .true
  if answer = 1 then return .true
  return .false
::method nextRecognitionEvent unguarded
  expose pythonObject providerName
  use arg providerSession, timeoutMs
  descriptor = pythonObject~next_recognition_event(providerSession, timeoutMs)
  if descriptor == .nil then return .nil
  if descriptor = '' then return .nil
  parse var descriptor kind '|' seq '|' textHex
  kind = translate(kind)
  if kind = 'WAIT' then return .nil
  if kind = 'END' then return .SpeechSTTEvent~new('END', seq, '', providerName)
  if kind \= 'PARTIAL' then do
    if kind \= 'FINAL' then raise syntax 88.900 array('unknown Python STT stream descriptor: ' || descriptor)
  end
  text = ''
  if textHex \= '' then text = x2c(textHex)
  return .SpeechSTTEvent~new(kind, seq, text, providerName)
::method cancelRecognition
  expose pythonObject
  use arg providerSession
  answer = pythonObject~cancel_recognition(providerSession)
  if translate(answer) = 'TRUE' then return .true
  if answer = 1 then return .true
  return .false

::class SpeechMacrospaceDuplexProvider subclass SpeechTTSProvider public
::method init
  expose pythonObject providerName audioFormat mediaType streamFormats
  use strict arg pythonObject, providerName = 'macrospace-duplex', audioFormat = .nil, mediaType = 'audio/wav'
  if pythonObject == .nil then raise syntax 88.900 array('resident Python object required')
  if providerName == .nil then providerName = 'macrospace-duplex'
  if audioFormat == .nil then audioFormat = .SpeechAudioFormat~new(24000, 1, 'S16LE', 'PCM')
  if mediaType == .nil then mediaType = 'audio/wav'
  streamFormats = .Directory~new
::method name
  expose providerName
  return providerName
::method formatForProfile
  expose audioFormat
  use strict arg profile = ''
  profile = translate(profile)
  if profile = 'TELEPHONY-8K' then return .SpeechAudioProfiles~telephonyNarrowband
  if profile = 'SPEECH-16K' then return .SpeechAudioProfiles~telephonyWideband
  return audioFormat
::method synthesize
  expose pythonObject providerName mediaType
  use arg request
  profile = request~audioProfile
  path = pythonObject~synthesize_to_file(request~text, request~voice, request~language, profile)
  artifact = .SpeechAudioArtifact~new(path, mediaType, self~formatForProfile(profile), providerName)
  return .SpeechTTSResult~new(artifact, providerName)
::method beginSynthesis
  expose pythonObject streamFormats
  use arg request
  profile = request~audioProfile
  session = pythonObject~begin_synthesis(request~text, request~voice, request~language, profile)
  streamFormats[session] = self~formatForProfile(profile)
  return session
::method nextSynthesisChunk unguarded
  expose pythonObject providerName streamFormats
  use arg providerSession, timeoutMs
  format = streamFormats[providerSession]
  if format == .nil then format = .SpeechAudioProfiles~azureTTS
  descriptor = pythonObject~next_synthesis_chunk(providerSession, timeoutMs)
  if descriptor == .nil then return .nil
  if descriptor = '' then return .nil
  parse var descriptor kind '|' seq '|' byteCount '|' ref
  kind = translate(kind)
  if kind = 'WAIT' then return .nil
  if kind = 'END' then do
    streamFormats~remove(providerSession)
    return .SpeechAudioChunk~new('END', seq, '', 0, format, providerName)
  end
  if kind \= 'DATA' then raise syntax 88.900 array('unknown Python TTS stream descriptor: ' || descriptor)
  return .SpeechAudioChunk~new('DATA', seq, ref, byteCount, format, providerName)
::method cancelSynthesis
  expose pythonObject streamFormats
  use arg providerSession
  answer = pythonObject~cancel_synthesis(providerSession)
  streamFormats~remove(providerSession)
  if translate(answer) = 'TRUE' then return .true
  if answer = 1 then return .true
  return .false
::method releaseSynthesisChunk
  expose pythonObject
  use arg chunkRef
  answer = pythonObject~release_synthesis_chunk(chunkRef)
  if translate(answer) = 'TRUE' then return .true
  if answer = 1 then return .true
  return .false
::method recognize
  expose pythonObject providerName
  use arg request
  text = pythonObject~transcribe_file(request~audio~ref, request~language)
  return .SpeechSTTResult~new(text, providerName, request~language, -1)
::method beginRecognition
  expose pythonObject
  use arg audioFormat, language, options
  return pythonObject~begin_recognition(language, audioFormat~sampleRate, 16, audioFormat~channels)
::method pushRecognitionChunk
  expose pythonObject
  use arg providerSession, chunkRef, byteCount
  answer = pythonObject~push_recognition_chunk(providerSession, chunkRef)
  if translate(answer) = 'TRUE' then return .true
  if answer = 1 then return .true
  return .false
::method endRecognitionInput
  expose pythonObject
  use arg providerSession
  answer = pythonObject~end_recognition_input(providerSession)
  if translate(answer) = 'TRUE' then return .true
  if answer = 1 then return .true
  return .false
::method nextRecognitionEvent unguarded
  expose pythonObject providerName
  use arg providerSession, timeoutMs
  descriptor = pythonObject~next_recognition_event(providerSession, timeoutMs)
  if descriptor == .nil then return .nil
  if descriptor = '' then return .nil
  parse var descriptor kind '|' seq '|' textHex
  kind = translate(kind)
  if kind = 'WAIT' then return .nil
  if kind = 'END' then return .SpeechSTTEvent~new('END', seq, '', providerName)
  if kind \= 'PARTIAL' then do
    if kind \= 'FINAL' then raise syntax 88.900 array('unknown Python STT stream descriptor: ' || descriptor)
  end
  text = ''
  if textHex \= '' then text = x2c(textHex)
  return .SpeechSTTEvent~new(kind, seq, text, providerName)
::method cancelRecognition
  expose pythonObject
  use arg providerSession
  answer = pythonObject~cancel_recognition(providerSession)
  if translate(answer) = 'TRUE' then return .true
  if answer = 1 then return .true
  return .false

::requires 'SpeechProviders.cls'
