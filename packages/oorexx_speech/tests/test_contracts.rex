call directory '../src'
req = .SpeechTTSRequest~new('hello', 'voice-a', 'en')
if req~text \= 'hello' then call fail 'TTS text'
fmt = .SpeechAudioFormat~new(16000, 1, 'S16LE', 'PCM')
a = .SpeechAudioArtifact~new('/tmp/x.wav', 'audio/wav', fmt, 'p')
sreq = .SpeechSTTRequest~new(a, 'en')
if sreq~audio~ref \= '/tmp/x.wav' then call fail 'STT artifact'
runtime = .SpeechRuntime~new
tracker = .SpeechTestConcurrencyTracker~new
c = .SpeechTTSChannel~new('c1', .SpeechTestTTSProvider~new('p', tracker, 0), .nil)
runtime~addChannel(c)
if runtime~count \= 1 then call fail 'runtime count'
sst = .SpeechSSTChannel~new('sst-1', .SpeechTestSTTProvider~new('sst-test', tracker, 0))
if sst~channelId \= 'sst-1' then call fail 'SST alias'
say 'PASS contracts'
exit 0
fail:
  parse arg why
  say 'FAIL' why
  exit 1
::requires 'SpeechChannels.cls'
::requires 'SpeechProviders.cls'
