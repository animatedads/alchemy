call directory '../src'

narrow = .SpeechAudioProfiles~named('telephony-8k')
wide = .SpeechAudioProfiles~named('speech-16k')
azure = .SpeechAudioProfiles~named('azure-tts-24k')
if narrow~sampleRate \= 8000 then call fail 'narrow'
if wide~sampleRate \= 16000 then call fail 'wide'
if azure~sampleRate \= 24000 then call fail 'azure'
opts = .Directory~new
opts['audioProfile'] = 'telephony-8k'
req = .SpeechTTSRequest~new('telephone test', '', 'en-GB', opts)
if req~audioProfile \= 'telephony-8k' then call fail 'request profile'
say 'PASS speech audio profiles telephony=8000 speech=16000 azure-tts=24000'
exit 0
fail:
  parse arg why
  say 'FAIL audio profiles' why
  exit 1
::requires 'SpeechCore.cls'
