call directory '../src'
fmt=.SpeechAudioProfiles~telephonyNarrowband
tracker=.SpeechTestConcurrencyTracker~new
ttsProvider=.SpeechTestStreamingTTSProvider~new('duplex-tts',tracker,0.20)
sttProvider=.SpeechTestStreamingSTTProvider~new('duplex-stt',tracker,0.20)
tts=.SpeechTTSChannel~new('duplex-tts-channel',ttsProvider)
stt=.SpeechSTTChannel~new('duplex-stt-channel',sttProvider)
source=.SessionTestSource~new(fmt,3)
sink=.SessionTestSink~new(.SpeechAudioProfiles~azureTTS)
session=.SpeechDuplexSession~new('session-1',tts,stt,source,sink)
request=.SpeechTTSRequest~new('duplex speech test','','en-GB')
call time 'R'
session~start(request,fmt,'en-GB',.Directory~new,320,1000,1000)
outcome=session~wait
elapsed=time('E')
if session~state \= 'COMPLETE' then call fail 'state=' || session~state
if outcome~playbackChunks \= 3 then call fail 'playback=' || outcome~playbackChunks
if outcome~captureChunks \= 3 then call fail 'capture=' || outcome~captureChunks
if sink~count \= 3 then call fail 'sink=' || sink~count
if outcome~recognitionEvents~items < 3 then call fail 'events=' || outcome~recognitionEvents~items
if left(outcome~finalText,6) \= 'final-' then call fail 'text=' || outcome~finalText
if tracker~peak < 2 then call fail 'peak=' || tracker~peak
say 'PASS duplex session elapsed=' || elapsed || ' peak=' || tracker~peak
exit 0
fail:
  parse arg why
  say 'FAIL duplex session' why
  exit 1
::class SessionTestSource subclass SpeechPCMSource public
::method init
  expose fmt remaining seq
  use strict arg fmt, remaining=3
  seq=0
::method audioFormat
  expose fmt
  return fmt
::method nextChunk unguarded
  expose fmt remaining seq
  use strict arg maximumBytes=320
  if remaining <= 0 then return .SpeechAudioChunk~new('END',seq,'',0,fmt,'session-test-source')
  seq+=1; remaining-=1
  return .SpeechAudioChunk~new('DATA',seq,'memory:session-capture:' || seq,maximumBytes,fmt,'session-test-source')
::method releaseChunk
  use strict arg chunk
  return .true
::method close
  return .true
::class SessionTestSink subclass SpeechPCMSink public
::method init
  expose fmt count
  use strict arg fmt
  count=0
::method audioFormat
  expose fmt
  return fmt
::method putChunk
  expose count
  use strict arg chunk
  count+=1
  return .true
::method close
  return .true
::method count
  expose count
  return count
::requires 'SpeechDuplexSession.cls'
::requires 'SpeechProviders.cls'
