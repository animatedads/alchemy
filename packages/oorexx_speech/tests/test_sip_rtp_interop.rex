/* Cross-package compatibility: Speech dev12 with the real SIP speech adapter
 * and RTP media object model. REXX_PATH must include Speech src, SIP src,
 * RTP src and SocketProvider source; the RTP native library must be loadable.
 */
say 'SPEECH SIP/RTP INTEROP DEV12 START'

call assertEq .SpeechBuild~api,'oorexx.speech/0.1','Speech API'
call assertEq .SipSpeechBridgeBuild~API,'sip.speech.bridge/0.1','SIP speech bridge API'
call assertEq .RtpBuild~API,'rtp/0.1','RTP API'

recognition=.CaptureRecognitionStream~new
consumer=.SipSpeechRecognitionConsumer~new(recognition,directory())
frame1=.RtpAudioFrame~new(copies('A',320),8000,1,'S16LE',0,160)
frame2=.RtpAudioFrame~new(copies('B',320),8000,1,'S16LE',8,160)
call assertTrue consumer~audioFrame(frame1),'inbound PCMU-decoded frame accepted'
call assertTrue consumer~audioFrame(frame2),'inbound PCMA-decoded frame accepted'
call assertEq recognition~chunks,2,'two STT chunks'
call assertEq recognition~bytes,640,'STT byte count'
call assertEq recognition~data,copies('A',320)||copies('B',320),'STT bytes exact'
call assertTrue consumer~endInput,'first endInput accepted'
call assertTrue recognition~ended,'recognition stream ended'
call assertFalse consumer~endInput,'second endInput is idempotent false'

format=.SpeechAudioProfiles~telephonyNarrowband
p1=SysTempFileName(directory()||'/speech-dev12-a-??????.pcm')
p2=SysTempFileName(directory()||'/speech-dev12-b-??????.pcm')
p3=SysTempFileName(directory()||'/speech-dev12-c-??????.pcm')
call writeBytes p1,copies('C',100)
call writeBytes p2,copies('D',220)
call writeBytes p3,copies('E',320)
stream=.FileSynthesisStream~new(.array~of( -
  .SpeechAudioChunk~new('DATA',1,p1,100,format,'speech-dev12'), -
  .SpeechAudioChunk~new('DATA',2,p2,220,format,'speech-dev12'), -
  .SpeechAudioChunk~new('DATA',3,p3,320,format,'speech-dev12'), -
  .SpeechAudioChunk~new('END',4,'',0,format,'speech-dev12')))
producer=.SipSpeechSynthesisProducer~new(stream,0,160)
out1=producer~nextAudioFrame(1)
out2=producer~nextAudioFrame(1)
out3=producer~nextAudioFrame(1)
call assertEq out1~data~length,320,'first RTP PCM frame length'
call assertEq out1~data,copies('C',100)||copies('D',220),'first frame crosses Speech chunks exactly'
call assertEq out2~data~length,320,'second RTP PCM frame length'
call assertEq out2~data,copies('E',320),'second frame exact'
call assertTrue out3==.nil,'producer terminal nil'
call assertEq producer~producedFrames,2,'producer frame counter'
call assertEq producer~producedBytes,640,'producer byte counter'
call assertEq stream~released,3,'each Speech DATA chunk released once'

q=SysTempFileName(directory()||'/speech-dev12-d-??????.pcm')
call writeBytes q,copies('F',320)
stream8=.FileSynthesisStream~new(.array~of( -
  .SpeechAudioChunk~new('DATA',1,q,320,format,'speech-dev12'), -
  .SpeechAudioChunk~new('END',2,'',0,format,'speech-dev12')))
producer8=.SipSpeechSynthesisProducer~new(stream8,8,160)
out8=producer8~nextAudioFrame(1)
call assertEq out8~payloadType,8,'payload 8 preserved'
call assertEq out8~sampleRate,8000,'RTP frame rate'
call assertEq out8~sampleFormat,'S16LE','RTP frame sample format'
call assertEq producer8~producedFrames,1,'independent producer counter'
call assertEq producer~producedFrames,2,'first producer counter unchanged'

call SysFileDelete p1
call SysFileDelete p2
call SysFileDelete p3
call SysFileDelete q

say 'PASS Speech dev12 / SIP speech bridge / RTP decoded-PCM compatibility'
exit 0

writeBytes: procedure
  use strict arg path,data
  remaining=charout(path,data,1)
  closeResult=stream(path,'C','CLOSE')
  if remaining<>0 then do
    say 'FAIL writeBytes' path
    exit 1
  end
  return

assertTrue: procedure
  use strict arg truth,label
  if truth then return
  say 'FAIL' label
  exit 1

assertFalse: procedure
  use strict arg truth,label
  if \truth then return
  say 'FAIL' label
  exit 1

assertEq: procedure
  use strict arg actual,expected,label
  if actual=expected then return
  say 'FAIL' label 'expected='expected 'actual='actual
  exit 1

::class CaptureRecognitionStream
::method init
  expose chunks bytes data ended
  chunks=0; bytes=0; data=''; ended=.false
::attribute chunks get
::attribute bytes get
::attribute data get
::attribute ended get
::method pushChunk
  expose chunks bytes data
  use strict arg chunk
  size=stream(chunk~ref,'C','QUERY SIZE')
  piece=charin(chunk~ref,1,size)
  closeResult=stream(chunk~ref,'C','CLOSE')
  chunks+=1
  bytes+=piece~length
  data=data||piece
  return .true
::method endInput
  expose ended
  ended=.true
  return .true

::class FileSynthesisStream
::method init
  expose chunks index released
  use strict arg chunks
  index=1; released=0
::attribute released get
::method nextChunk
  expose chunks index
  use strict arg timeoutMs=1000
  if index>chunks~items then return .nil
  item=chunks[index]
  index+=1
  return item
::method releaseChunk
  expose released
  use strict arg chunk
  released+=1
  return .true

::requires 'SpeechCore.cls'
::requires 'sip_speech.cls'
