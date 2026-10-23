call directory '../src'

fmt = .SpeechAudioProfiles~telephonyNarrowband
if fmt~sampleRate \= 8000 then call fail 'telephony rate'
if fmt~channels \= 1 then call fail 'telephony channels'
if fmt~sampleFormat \= 'S16LE' then call fail 'telephony sample format'

tracker = .SpeechTestConcurrencyTracker~new
p1 = .SpeechTestStreamingSTTProvider~new('stt-stream-1', tracker, 0.20)
p2 = .SpeechTestStreamingSTTProvider~new('stt-stream-2', tracker, 0.20)
p3 = .SpeechTestStreamingSTTProvider~new('stt-stream-3', tracker, 0.20)
p4 = .SpeechTestStreamingSTTProvider~new('stt-stream-4', tracker, 0.20)
c1 = .SpeechSTTChannel~new('stt-1', p1)
c2 = .SpeechSTTChannel~new('stt-2', p2)
c3 = .SpeechSTTChannel~new('stt-3', p3)
c4 = .SpeechSTTChannel~new('stt-4', p4)
s1 = c1~beginRecognition(fmt, 'en-GB'); s2 = c2~beginRecognition(fmt, 'en-GB')
s3 = c3~beginRecognition(fmt, 'en-GB'); s4 = c4~beginRecognition(fmt, 'en-GB')
chunk1 = .SpeechAudioChunk~new('DATA', 1, 'memory:pcm1', 320, fmt, 'rtp-test')
chunk2 = .SpeechAudioChunk~new('DATA', 2, 'memory:pcm2', 320, fmt, 'rtp-test')
if \s1~pushChunk(chunk1) then call fail 'push 1'
if \s1~pushChunk(chunk2) then call fail 'push 2'
if \s2~pushChunk(chunk1) then call fail 'push 2a'
if \s3~pushChunk(chunk1) then call fail 'push 3a'
if \s4~pushChunk(chunk1) then call fail 'push 4a'
call time 'R'
m1 = s1~start('NEXTEVENT', 1000); m2 = s2~start('NEXTEVENT', 1000)
m3 = s3~start('NEXTEVENT', 1000); m4 = s4~start('NEXTEVENT', 1000)
e1 = m1~result; e2 = m2~result; e3 = m3~result; e4 = m4~result
elapsed = time('E')
if tracker~peak < 4 then call fail 'stream peak=' || tracker~peak
if elapsed >= 0.70 then call fail 'stream elapsed=' || elapsed
if \e1~isPartial then call fail 'first event not partial'
if e1~text \= 'partial-2' then call fail 'partial text=' || e1~text
finalEvent = s1~nextEvent(1000)
if \finalEvent~isFinal then call fail 'final missing'
if finalEvent~text \= 'final-2' then call fail 'final text'
if \s1~endInput then call fail 'end input'
endEvent = s1~nextEvent(1000)
if \endEvent~isEnd then call fail 'end event'
if s1~state \= 'ENDED' then call fail 'stream state'
if c1~state \= 'IDLE' then call fail 'channel state'
final = s1~finalResult
if final~text \= 'final-2' then call fail 'final result text'
say 'PASS streaming STT peak=' || tracker~peak || ' elapsed=' || elapsed || ' profile=telephony-8k'
exit 0
fail:
  parse arg why
  say 'FAIL streaming STT' why
  exit 1
::requires 'SpeechChannels.cls'
::requires 'SpeechProviders.cls'
