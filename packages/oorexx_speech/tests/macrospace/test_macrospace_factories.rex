modulePath = value('OOREXX_SPEECH_PYDIR',, 'ENVIRONMENT')
if modulePath == '' then raise syntax 93.900 array('OOREXX_SPEECH_PYDIR required')
local = .SpeechMacrospaceFactory~localDuplex(modulePath, '', 'small', 'cpu')
if local~name \== 'local-piper-faster-whisper' then raise syntax 93.900 array('local factory failed')
cloud = .SpeechMacrospaceFactory~cloudDuplex(modulePath, 'tts-probe', 'stt-probe', 'voice-probe')
if cloud~name \== 'cloud-openai' then raise syntax 93.900 array('cloud factory failed')
return 'PASS macrospace local+cloud factories'

::requires 'SpeechMacrospaceFactory.cls'
