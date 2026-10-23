/* Regression for omitted optional arguments and RESULT clobbering. */

fake = .FakePythonSpeech~new
provider = .SpeechMacrospaceDuplexProvider~new(fake, 'fake-azure')
channel = .SpeechTTSChannel~new('defaults', provider)
request = .SpeechTTSRequest~new('hello')
ttsResult = channel~synthesize(request)
artifact = ttsResult~artifact
format = artifact~audioFormat

if ttsResult~provider \= 'fake-azure' then call fail 'provider default path'
if artifact~mediaType \= 'audio/wav' then call fail 'media type default'
if format~sampleRate \= 24000 then call fail 'sampleRate default'
if format~channels \= 1 then call fail 'channels default'
if format~sampleFormat \= 'S16LE' then call fail 'sampleFormat default'
if format~encoding \= 'PCM' then call fail 'encoding default'

call SysSleep 0
if ttsResult~provider \= 'fake-azure' then call fail 'ttsResult survived CALL'

say 'PASS optional defaults and RESULT isolation'
exit 0

fail: procedure
  parse arg what
  say 'FAIL' what
  exit 1

::class FakePythonSpeech
::method synthesize_to_file
  use arg text, voice, language
  return '/tmp/fake.wav'
::method transcribe_file
  use arg path, language
  return 'fake transcript'

::requires 'SpeechCore.cls'
::requires 'SpeechProviders.cls'
::requires 'SpeechMacrospace.cls'
::requires 'SpeechChannels.cls'
