/* Dynamic intention discovery regression. */
parse source . . here
root=filespec('L',here)||filespec('P',here)||'..'
call addPath root'/src'

tracker=.SpeechTestConcurrencyTracker~new
runtime=.SpeechRuntime~new
tts=.SpeechTTSChannel~new('tts-a',.SpeechTestTTSProvider~new('tts',tracker,0.20),.nil)
stt=.SpeechSTTChannel~new('stt-a',.SpeechTestSTTProvider~new('stt',tracker,0.20))
runtime~addChannel(tts)
runtime~addChannel(stt)
provider=.SpeechIntentionProvider~new

first=provider~discover(runtime)
call assert first~count=3,'initial discovery should contain TTS, STT and duplex intentions'
call assert first~byId('speech.tts.channel.tts-a')~target==tts,'TTS target was flattened/reconstructed'
call assert first~byId('speech.stt.channel.stt-a')~target==stt,'STT target was flattened/reconstructed'
call assert first~byId('speech.duplex.session')<>.nil,'duplex intention missing when both lanes are available'

msg=tts~synthesizeAsync(.SpeechTTSRequest~new('busy now'))
call SysSleep 0.05
second=provider~discover(runtime)
ttsIntent=second~byId('speech.tts.channel.tts-a')
call assert ttsIntent~state='BUSY','busy channel remained AVAILABLE in fresh discovery'
call assert second~byId('speech.duplex.session')==.nil,'duplex remained available while TTS lane was busy'
done = msg~result

third=provider~discover(runtime)
call assert third~byId('speech.tts.channel.tts-a')~state='AVAILABLE','channel did not return to AVAILABLE after work'
call assert third~byId('speech.duplex.session')<>.nil,'duplex did not reappear after lane became idle'
call assert third~generation>second~generation,'discovery generation did not advance'

say 'PASS dynamic speech intentions generations='third~generation
exit 0

assert: procedure
  use arg ok,msg
  if \ok then do
    say 'FAIL' msg
    exit 1
  end
  return

addPath: procedure
  use arg path
  old=value('REXX_PATH',,'ENVIRONMENT')
  if old='' then call value 'REXX_PATH',path,'ENVIRONMENT'
  else call value 'REXX_PATH',path':'old,'ENVIRONMENT'
  return

::requires 'SpeechIntentions.cls'
::requires 'SpeechProviders.cls'
