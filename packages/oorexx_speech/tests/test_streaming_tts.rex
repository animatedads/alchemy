call directory '../src'

tracker = .SpeechTestConcurrencyTracker~new
p1 = .SpeechTestStreamingTTSProvider~new('stream-1', tracker, 0.20)
p2 = .SpeechTestStreamingTTSProvider~new('stream-2', tracker, 0.20)
p3 = .SpeechTestStreamingTTSProvider~new('stream-3', tracker, 0.20)
p4 = .SpeechTestStreamingTTSProvider~new('stream-4', tracker, 0.20)

c1 = .SpeechTTSChannel~new('tts-stream-1', p1, .nil)
c2 = .SpeechTTSChannel~new('tts-stream-2', p2, .nil)
c3 = .SpeechTTSChannel~new('tts-stream-3', p3, .nil)
c4 = .SpeechTTSChannel~new('tts-stream-4', p4, .nil)

s1 = c1~beginSynthesis(.SpeechTTSRequest~new('one'))
s2 = c2~beginSynthesis(.SpeechTTSRequest~new('two'))
s3 = c3~beginSynthesis(.SpeechTTSRequest~new('three'))
s4 = c4~beginSynthesis(.SpeechTTSRequest~new('four'))

if c1~state \= 'STREAMING' then call fail 'channel not streaming'
call time 'R'
m1 = s1~start('NEXTCHUNK', 1000)
m2 = s2~start('NEXTCHUNK', 1000)
m3 = s3~start('NEXTCHUNK', 1000)
m4 = s4~start('NEXTCHUNK', 1000)
a1 = m1~result; a2 = m2~result; a3 = m3~result; a4 = m4~result
elapsed = time('E')

if tracker~peak < 4 then call fail 'stream peak=' || tracker~peak
if elapsed >= 0.70 then call fail 'stream elapsed=' || elapsed
if a1~sequence \= 1 then call fail 'stream1 sequence'
if a4~byteCount \= 9600 then call fail 'stream4 bytes'
if \a1~isData then call fail 'stream1 not DATA'

b = s1~nextChunk(1000)
c = s1~nextChunk(1000)
e = s1~nextChunk(1000)
if b~sequence \= 2 then call fail 'stream sequence 2'
if c~sequence \= 3 then call fail 'stream sequence 3'
if \e~isEnd then call fail 'stream END missing'
if s1~state \= 'ENDED' then call fail 'stream state not ENDED'
if c1~state \= 'IDLE' then call fail 'channel did not return IDLE'

cancelProvider = .SpeechTestStreamingTTSProvider~new('cancel-test', .nil, 0)
cancelChannel = .SpeechTTSChannel~new('cancel-channel', cancelProvider, .nil)
cancelStream = cancelChannel~beginSynthesis(.SpeechTTSRequest~new('cancel me'))
if \cancelStream~cancel then call fail 'cancel returned false'
if cancelStream~state \= 'CANCELLED' then call fail 'cancel state'
if cancelChannel~state \= 'IDLE' then call fail 'cancel channel state'

say 'PASS streaming TTS peak=' || tracker~peak || ' elapsed=' || elapsed
exit 0
fail:
  parse arg why
  say 'FAIL streaming TTS' why
  exit 1
::requires 'SpeechChannels.cls'
::requires 'SpeechProviders.cls'
