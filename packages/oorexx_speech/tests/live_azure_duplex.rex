/* Live full-duplex local audio <-> Azure Speech through two resident providers. */
parse arg modulePath captureFifo playbackFifo
if modulePath='' then do; say 'FAIL module path required'; exit 2; end
if captureFifo='' then do; say 'FAIL capture FIFO required'; exit 2; end
if playbackFifo='' then do; say 'FAIL playback FIFO required'; exit 2; end
key=value('OOREXX_SPEECH_AZURE_KEY',,'ENVIRONMENT'); if key='' then key=value('SPEECH_KEY',,'ENVIRONMENT')
region=value('OOREXX_SPEECH_AZURE_REGION',,'ENVIRONMENT'); if region='' then region=value('SPEECH_REGION',,'ENVIRONMENT')
endpoint=value('OOREXX_SPEECH_AZURE_ENDPOINT',,'ENVIRONMENT'); if endpoint='' then endpoint=value('ENDPOINT',,'ENVIRONMENT')
if key='' then do; say 'FAIL Azure Speech key is not configured'; exit 3; end
if region='' then do
  if endpoint='' then do; say 'FAIL Azure Speech region or endpoint is required'; exit 3; end
end
voice=value('OOREXX_SPEECH_AZURE_VOICE',,'ENVIRONMENT'); if voice='' then voice='en-GB-SoniaNeural'
language=value('OOREXX_SPEECH_STT_LANGUAGE',,'ENVIRONMENT'); if language='' then language='en-GB'
profile=value('OOREXX_SPEECH_AUDIO_PROFILE',,'ENVIRONMENT'); if profile='' then profile='speech-16k'
text=value('OOREXX_SPEECH_TEST_TEXT',,'ENVIRONMENT'); if text='' then text='Hello. Speak while this sentence is playing. ooRexx is running both directions at once.'
fmt=.SpeechAudioProfiles~byName(profile)
options=.Directory~new; options['audioProfile']=profile
ttsProvider=.SpeechMacrospaceFactory~azureDuplex(modulePath,key,region,endpoint,voice)
sttProvider=.SpeechMacrospaceFactory~azureDuplex(modulePath,key,region,endpoint,'')
tts=.SpeechTTSChannel~new('azure-duplex-tts',ttsProvider,.nil)
stt=.SpeechSTTChannel~new('azure-duplex-stt',sttProvider)
source=.SpeechFifoPCMSource~new(captureFifo,fmt,'/tmp','azure-duplex-capture')
sink=.SpeechFifoPCMSink~new(playbackFifo,fmt)
session=.SpeechDuplexSession~new('azure-live-duplex',tts,stt,source,sink)
request=.SpeechTTSRequest~new(text,voice,language,options)
call time 'R'
session~start(request,fmt,language,.Directory~new,640,5000,1000)
outcome=session~wait
elapsed=time('E')
say 'PASS Azure live full-duplex speech session'
say 'PROFILE' profile
say 'VOICE' voice
say 'PLAYBACK_CHUNKS' outcome~playbackChunks
say 'CAPTURE_CHUNKS' outcome~captureChunks
say 'EVENTS' outcome~recognitionEvents~items
say 'TRANSCRIPT' outcome~finalText
say 'SECONDS' elapsed
exit 0
::requires 'SpeechCore.cls'
::requires 'SpeechChannels.cls'
::requires 'SpeechMacrospaceFactory.cls'
::requires 'SpeechLocalAudio.cls'
::requires 'SpeechDuplexSession.cls'
