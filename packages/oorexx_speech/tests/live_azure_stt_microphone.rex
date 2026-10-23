/* Live local PCM FIFO microphone -> Azure streaming STT. */
parse arg modulePath fifoPath
if modulePath='' then do; say 'FAIL module path required'; exit 2; end
if fifoPath='' then do; say 'FAIL capture FIFO required'; exit 2; end
key=value('OOREXX_SPEECH_AZURE_KEY',,'ENVIRONMENT'); if key='' then key=value('SPEECH_KEY',,'ENVIRONMENT')
region=value('OOREXX_SPEECH_AZURE_REGION',,'ENVIRONMENT'); if region='' then region=value('SPEECH_REGION',,'ENVIRONMENT')
endpoint=value('OOREXX_SPEECH_AZURE_ENDPOINT',,'ENVIRONMENT'); if endpoint='' then endpoint=value('ENDPOINT',,'ENVIRONMENT')
if key='' then do; say 'FAIL Azure Speech key is not configured'; exit 3; end
if region='' then do
  if endpoint='' then do; say 'FAIL Azure Speech region or endpoint is required'; exit 3; end
end
language=value('OOREXX_SPEECH_STT_LANGUAGE',,'ENVIRONMENT'); if language='' then language='en-GB'
profile=value('OOREXX_SPEECH_AUDIO_PROFILE',,'ENVIRONMENT'); if profile='' then profile='speech-16k'
fmt=.SpeechAudioProfiles~byName(profile)
provider=.SpeechMacrospaceFactory~azureDuplex(modulePath,key,region,endpoint,'')
channel=.SpeechSTTChannel~new('azure-live-microphone',provider)
stt=channel~beginRecognition(fmt,language)
source=.SpeechFifoPCMSource~new(fifoPath,fmt,'/tmp','azure-live-mic')
controller=.SpeechLocalAudioController~new
chunks=controller~feedRecognition(source,stt,640)
finals=0
do forever
  event=stt~nextEvent(5000)
  if event == .nil then iterate
  if event~isPartial then say 'PARTIAL' event~text
  if event~isFinal then do; say 'FINAL' event~text; finals += 1; end
  if event~isEnd then leave
end
answer=stt~finalResult
say 'PASS Azure STT live microphone'
say 'PROFILE' profile
say 'CHUNKS' chunks
say 'FINAL_EVENTS' finals
say 'TRANSCRIPT' answer~text
exit 0
::requires 'SpeechCore.cls'
::requires 'SpeechChannels.cls'
::requires 'SpeechMacrospaceFactory.cls'
::requires 'SpeechLocalAudio.cls'
