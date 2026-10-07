call directory '../src'
tracker = .SpeechTestConcurrencyTracker~new
runtime = .SpeechRuntime~new

t1 = .SpeechTTSChannel~new('tts-1', .SpeechTestTTSProvider~new('local-tts-1', tracker, 0.50), .nil)
t2 = .SpeechTTSChannel~new('tts-2', .SpeechTestTTSProvider~new('cloud-tts-2', tracker, 0.50), .nil)
s1 = .SpeechSTTChannel~new('stt-1', .SpeechTestSTTProvider~new('local-stt-1', tracker, 0.50))
s2 = .SpeechSTTChannel~new('stt-2', .SpeechTestSTTProvider~new('cloud-stt-2', tracker, 0.50))
runtime~addChannel(t1); runtime~addChannel(t2); runtime~addChannel(s1); runtime~addChannel(s2)

fmt = .SpeechAudioFormat~new(16000, 1, 'S16LE', 'PCM')
a1 = .SpeechAudioArtifact~new('a1.wav', 'audio/wav', fmt, 'test')
a2 = .SpeechAudioArtifact~new('a2.wav', 'audio/wav', fmt, 'test')

call time 'R'
m1 = t1~synthesizeAsync(.SpeechTTSRequest~new('one', 'v1', 'en'))
m2 = t2~synthesizeAsync(.SpeechTTSRequest~new('two', 'v2', 'en'))
m3 = s1~recognizeAsync(.SpeechSTTRequest~new(a1, 'en'))
m4 = s2~recognizeAsync(.SpeechSTTRequest~new(a2, 'en'))

r1 = m1~result
r2 = m2~result
r3 = m3~result
r4 = m4~result
elapsed = time('E')

if tracker~completed \= 4 then call fail 'completed=' || tracker~completed
if tracker~peak < 4 then call fail 'peak=' || tracker~peak
if elapsed >= 1.60 then call fail 'elapsed=' || elapsed
if r1~artifact~ref \= 'memory:one' then call fail 'tts1 result'
if r2~artifact~ref \= 'memory:two' then call fail 'tts2 result'
if r3~text \= 'transcript:a1.wav' then call fail 'stt1 result'
if r4~text \= 'transcript:a2.wav' then call fail 'stt2 result'
say 'PASS multi-channel peak=' || tracker~peak || ' elapsed=' || elapsed
exit 0
fail:
  parse arg why
  say 'FAIL multi-channel' why
  exit 1
::requires 'SpeechChannels.cls'
::requires 'SpeechProviders.cls'
