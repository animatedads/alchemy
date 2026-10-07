/* Optional Python Macrospace v0.31.7-rexxfirst2 class-loading convenience.
 * This file is deliberately separate from the provider-neutral speech core.
 * It requires the Macrospace AlchemyPythonClass surface (animals.cls).
 */

::class SpeechMacrospaceFactory public
::method localDuplex class
  use strict arg modulePath, piperModel = '', whisperModel = 'small', device = 'auto'
  cls = .AlchemyPythonClass~loadCls('oorexx_speech_providers', 'LocalPiperWhisperProvider', modulePath)
  py = cls~new(piperModel, whisperModel, device)
  return .SpeechMacrospaceDuplexProvider~new(py, 'local-piper-faster-whisper')

::method cloudDuplex class
  use strict arg modulePath, ttsModel, sttModel, defaultVoice = ''
  cls = .AlchemyPythonClass~loadCls('oorexx_speech_providers', 'OpenAICloudSpeechProvider', modulePath)
  py = cls~new(ttsModel, sttModel, defaultVoice)
  return .SpeechMacrospaceDuplexProvider~new(py, 'cloud-openai')

::method azureDuplex class
  use strict arg modulePath, subscriptionKey = '', region = '', endpoint = '', defaultVoice = '', recognitionTimeout = 3600
  cls = .AlchemyPythonClass~loadCls('oorexx_speech_providers', 'AzureSpeechProvider', modulePath)
  py = cls~new(subscriptionKey, region, endpoint, defaultVoice, recognitionTimeout)
  return .SpeechMacrospaceDuplexProvider~new(py, 'cloud-azure-speech')

::requires 'SpeechMacrospace.cls'
::requires 'animals.cls'
