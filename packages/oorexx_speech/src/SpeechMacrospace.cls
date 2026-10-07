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
 * This keeps the first executable crossing conservative while leaving live PCM
 * streaming to a later provider contract once the SIP/local audio controller is
 * available.
 */

::class SpeechMacrospaceTTSProvider subclass SpeechTTSProvider public
::method init
  expose pythonObject providerName audioFormat mediaType
  use arg pythonObject, providerName, audioFormat, mediaType
  if pythonObject == .nil then raise syntax 88.900 array('resident Python object required')
  if providerName == .nil then providerName = 'macrospace-tts'
  if audioFormat == .nil then audioFormat = .SpeechAudioFormat~new(24000, 1, 'S16LE', 'PCM')
  if mediaType == .nil then mediaType = 'audio/wav'
::method name
  expose providerName
  return providerName
::method synthesize
  expose pythonObject providerName audioFormat mediaType
  use arg request
  path = pythonObject~synthesize_to_file(request~text, request~voice, request~language)
  if path == .nil then raise syntax 88.900 array('Python TTS provider returned no artifact path')
  if path = '' then raise syntax 88.900 array('Python TTS provider returned no artifact path')
  artifact = .SpeechAudioArtifact~new(path, mediaType, audioFormat, providerName)
  return .SpeechTTSResult~new(artifact, providerName)

::class SpeechMacrospaceSTTProvider subclass SpeechSTTProvider public
::method init
  expose pythonObject providerName
  use arg pythonObject, providerName
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

::class SpeechMacrospaceDuplexProvider subclass SpeechTTSProvider public
::method init
  expose pythonObject providerName audioFormat mediaType
  use arg pythonObject, providerName, audioFormat, mediaType
  if pythonObject == .nil then raise syntax 88.900 array('resident Python object required')
  if providerName == .nil then providerName = 'macrospace-duplex'
  if audioFormat == .nil then audioFormat = .SpeechAudioFormat~new(24000, 1, 'S16LE', 'PCM')
  if mediaType == .nil then mediaType = 'audio/wav'
::method name
  expose providerName
  return providerName
::method synthesize
  expose pythonObject providerName audioFormat mediaType
  use arg request
  path = pythonObject~synthesize_to_file(request~text, request~voice, request~language)
  artifact = .SpeechAudioArtifact~new(path, mediaType, audioFormat, providerName)
  return .SpeechTTSResult~new(artifact, providerName)
::method recognize
  expose pythonObject providerName
  use arg request
  text = pythonObject~transcribe_file(request~audio~ref, request~language)
  return .SpeechSTTResult~new(text, providerName, request~language, -1)

::requires 'SpeechProviders.cls'
