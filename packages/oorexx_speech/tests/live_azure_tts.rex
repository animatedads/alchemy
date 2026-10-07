/*
 * Live Azure TTS smoke test.
 *
 * Required environment:
 *   OOREXX_SPEECH_AZURE_KEY (or SPEECH_KEY)
 *   OOREXX_SPEECH_AZURE_REGION (or SPEECH_REGION), unless endpoint supplied
 *
 * Optional:
 *   OOREXX_SPEECH_AZURE_ENDPOINT (or ENDPOINT)
 *   OOREXX_SPEECH_AZURE_VOICE (default en-GB-SoniaNeural)
 *   OOREXX_SPEECH_TEST_TEXT
 *
 * Argument 1: absolute/relative path to this package's python directory.
 */

parse arg modulePath
if modulePath = '' then do
  say 'FAIL module path required'
  say 'usage: rexx tests/live_azure_tts.rex /path/to/oorexx_speech/python'
  exit 2
end

voice = value('OOREXX_SPEECH_AZURE_VOICE',, 'ENVIRONMENT')
if voice = '' then voice = 'en-GB-SoniaNeural'
text = value('OOREXX_SPEECH_TEST_TEXT',, 'ENVIRONMENT')
if text = '' then text = 'Hello. This is the ooRexx Azure text to speech test.'

key = value('OOREXX_SPEECH_AZURE_KEY',, 'ENVIRONMENT')
if key = '' then key = value('SPEECH_KEY',, 'ENVIRONMENT')
if key = '' then do
  say 'FAIL Azure Speech key is not configured'
  exit 3
end

region = value('OOREXX_SPEECH_AZURE_REGION',, 'ENVIRONMENT')
if region = '' then region = value('SPEECH_REGION',, 'ENVIRONMENT')
endpoint = value('OOREXX_SPEECH_AZURE_ENDPOINT',, 'ENVIRONMENT')
if endpoint = '' then endpoint = value('ENDPOINT',, 'ENVIRONMENT')
if region = '' then do
  if endpoint = '' then do
    say 'FAIL Azure Speech region or endpoint is required'
    exit 3
  end
end

provider = .SpeechMacrospaceFactory~azureDuplex(modulePath, key, region, endpoint, voice)
channel = .SpeechTTSChannel~new('azure-live-tts', provider)
request = .SpeechTTSRequest~new(text, voice, 'en-GB')

signal on syntax name failed
signal on error name failed
signal on failure name failed

result = channel~synthesize(request)
artifact = result~artifact
path = artifact~ref

exists = stream(path, 'C', 'QUERY EXISTS')
if exists = '' then do
  say 'FAIL Azure returned artifact does not exist:' path
  exit 4
end

header = charin(path, 1, 12)
call stream path, 'C', 'CLOSE'
if length(header) < 12 then do
  say 'FAIL Azure artifact is too short to be a WAV:' path
  exit 4
end
if left(header, 4) \= 'RIFF' then do
  say 'FAIL Azure artifact has no RIFF header:' path
  exit 4
end
if substr(header, 9, 4) \= 'WAVE' then do
  say 'FAIL Azure artifact has no WAVE signature:' path
  exit 4
end

say 'PASS Azure TTS live smoke'
say 'PROVIDER' result~provider
say 'VOICE' voice
say 'FORMAT' artifact~audioFormat~sampleRate artifact~audioFormat~channels artifact~audioFormat~sampleFormat artifact~audioFormat~encoding
say 'ARTIFACT' path
say 'TEXT' text
exit 0

failed:
  say 'FAIL Azure TTS live smoke'
  say 'CONDITION' condition('C') condition('D')
  exit 5

::requires 'SpeechCore.cls'
::requires 'SpeechChannels.cls'
::requires 'SpeechMacrospaceFactory.cls'
