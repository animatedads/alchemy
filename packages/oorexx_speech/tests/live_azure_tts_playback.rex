/* Live Azure streaming TTS -> local PCM FIFO playback. */
parse arg modulePath fifoPath
if modulePath = '' then do; say 'FAIL module path required'; exit 2; end
if fifoPath = '' then do; say 'FAIL playback FIFO required'; exit 2; end
key=value('OOREXX_SPEECH_AZURE_KEY',,'ENVIRONMENT'); if key='' then key=value('SPEECH_KEY',,'ENVIRONMENT')
region=value('OOREXX_SPEECH_AZURE_REGION',,'ENVIRONMENT'); if region='' then region=value('SPEECH_REGION',,'ENVIRONMENT')
endpoint=value('OOREXX_SPEECH_AZURE_ENDPOINT',,'ENVIRONMENT'); if endpoint='' then endpoint=value('ENDPOINT',,'ENVIRONMENT')
if key='' then do; say 'FAIL Azure Speech key is not configured'; exit 3; end
if region='' then do
  if endpoint='' then do; say 'FAIL Azure Speech region or endpoint is required'; exit 3; end
end
voice=value('OOREXX_SPEECH_AZURE_VOICE',,'ENVIRONMENT'); if voice='' then voice='en-GB-SoniaNeural'
text=value('OOREXX_SPEECH_TEST_TEXT',,'ENVIRONMENT'); if text='' then text='Hello. This is live streamed audio from ooRexx through Microsoft Azure.'
profile=value('OOREXX_SPEECH_AUDIO_PROFILE',,'ENVIRONMENT'); if profile='' then profile='azure-tts-24k'
options=.Directory~new; options['audioProfile']=profile
provider=.SpeechMacrospaceFactory~azureDuplex(modulePath,key,region,endpoint,voice)
channel=.SpeechTTSChannel~new('azure-live-device',provider,.nil)
request=.SpeechTTSRequest~new(text,voice,'en-GB',options)
fmt=.SpeechAudioProfiles~byName(profile)
sink=.SpeechFifoPCMSink~new(fifoPath,fmt)
controller=.SpeechLocalAudioController~new
tts=channel~beginSynthesis(request)
call time 'R'
count=controller~playSynthesis(tts,sink,5000)
elapsed=time('E')
if count < 1 then do; say 'FAIL Azure playback returned no chunks'; exit 4; end
say 'PASS Azure TTS live local playback'
say 'PROVIDER' channel~providerName
say 'VOICE' voice
say 'PROFILE' profile
say 'CHUNKS' count
say 'BYTES' sink~bytesWritten
say 'SECONDS' elapsed
exit 0
::requires 'SpeechCore.cls'
::requires 'SpeechChannels.cls'
::requires 'SpeechMacrospaceFactory.cls'
::requires 'SpeechLocalAudio.cls'
