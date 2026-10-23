#!/usr/bin/env rexx
say 'SIP SPEECH ADAPTER PROBE START'

tmp=directory()
recognition=.FakeRecognitionStream~new
consumer=.SipSpeechRecognitionConsumer~new(recognition,tmp)
frame=.FakeRtpFrame~new(copies('A',320))
call assertTrue consumer~audioFrame(frame),'inbound frame accepted'
call assertEq recognition~chunks,1,'one STT chunk'
call assertEq recognition~bytes,320,'STT byte count'
call assertEq recognition~lastData,copies('A',320),'STT received exact PCM'
call assertTrue consumer~endInput,'STT end input'
call assertTrue recognition~ended,'recognition ended'

format=.SpeechAudioProfiles~telephonyNarrowband
path1=SysTempFileName(tmp||'/sip-speech-test-a-??????.pcm')
path2=SysTempFileName(tmp||'/sip-speech-test-b-??????.pcm')
call writeBytes path1,copies('B',200)
call writeBytes path2,copies('C',200)
stream=.FakeSynthesisStream~new(.array~of( -
  .SpeechAudioChunk~new('DATA',1,path1,200,format,'fake'), -
  .SpeechAudioChunk~new('DATA',2,path2,200,format,'fake'), -
  .SpeechAudioChunk~new('END',3,'',0,format,'fake')))
producer=.SipSpeechSynthesisProducer~new(stream,0,160)
out1=producer~nextAudioFrame(1)
out2=producer~nextAudioFrame(1)
out3=producer~nextAudioFrame(1)
call assertEq out1~data~length,320,'first RTP PCM frame is 20ms/320 bytes'
call assertEq out1~data,copies('B',200)||copies('C',120),'chunk boundary does not leak into RTP framing'
call assertEq out2~data~length,80,'terminal remainder preserved'
call assertEq out2~data,copies('C',80),'terminal remainder exact'
call assertTrue out3==.nil,'producer ends cleanly'
call assertEq producer~producedFrames,2,'two RTP PCM frames produced'
call assertEq producer~producedBytes,400,'all TTS PCM bytes produced'
call assertEq stream~released,2,'Speech chunks released by adapter'
call SysFileDelete path1
call SysFileDelete path2

say 'PASS independent SIP AudioIn/STT and AudioOut/TTS PCM adapters'
exit 0

writeBytes: procedure
  use arg path,data
  remaining=charout(path,data,1)
  closeResult=stream(path,'C','CLOSE')
  if remaining<>0 then do
    say 'FAIL writeBytes' path
    exit 1
  end
  return

assertTrue: procedure
  use arg truth,label
  if truth then return
  say 'FAIL' label
  exit 1

assertEq: procedure
  use arg actual,expected,label
  if actual=expected then return
  say 'FAIL' label 'expected='expected 'actual='actual
  exit 1

::class FakeRtpFrame
::method init
  expose data
  use strict arg data
::attribute data get
::method sampleRate
  return 8000
::method channels
  return 1
::method sampleFormat
  return 'S16LE'

::class FakeRecognitionStream
::method init
  expose chunks bytes lastData ended
  chunks=0; bytes=0; lastData=''; ended=.false
::attribute chunks get
::attribute bytes get
::attribute lastData get
::attribute ended get
::method pushChunk
  expose chunks bytes lastData
  use strict arg chunk
  size=stream(chunk~ref,'C','QUERY SIZE')
  lastData=charin(chunk~ref,1,size)
  closeResult=stream(chunk~ref,'C','CLOSE')
  chunks+=1
  bytes+=lastData~length
  return .true
::method endInput
  expose ended
  ended=.true
  return .true

::class FakeSynthesisStream
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

::requires 'sip_speech.cls'