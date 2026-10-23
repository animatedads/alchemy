/* Optional SIP <-> Speech PCM adapters.
 *
 * These adapters preserve the architectural split:
 *   - SIP owns signalling/control.
 *   - RTP owns packet/media framing.
 *   - Speech owns STT/TTS session semantics.
 *
 * The adapters do not own SipCallControl, SipInboundAudio, SipOutboundAudio,
 * SpeechSTTStream or SpeechTTSStream lifecycles.  They only translate the
 * already-decoded PCM seam between independently managed objects.
 */
::class SipSpeechBridgeBuild public
::constant VERSION "0.1-dev15"
::constant API "sip.speech.bridge/0.1"

::class SipSpeechAdapters public
::method recognitionConsumer class
  use strict arg recognitionStream, temporaryDirectory=""
  return .SipSpeechRecognitionConsumer~new(recognitionStream, temporaryDirectory)
::method synthesisProducer class
  use strict arg synthesisStream, payloadType=0, frameSamples=160
  return .SipSpeechSynthesisProducer~new(synthesisStream, payloadType, frameSamples)

/* Push-side adapter for SipInboundAudio~attachConsumer().  Each received RTP
 * audio frame is already decoded PCM.  The current Speech streaming contract
 * uses short-lived artifact refs for bulk PCM, so this adapter materialises
 * one temporary PCM artifact per accepted frame and removes it immediately
 * after Speech has synchronously consumed it.
 */
::class SipSpeechRecognitionConsumer public
::method init
  expose recognitionStream temporaryDirectory sequence acceptedFrames acceptedBytes ended
  use strict arg recognitionStream, temporaryDirectory=""
  if recognitionStream==.nil then raise syntax 88.900 array("recognition stream required")
  if temporaryDirectory==.nil then temporaryDirectory=""
  if temporaryDirectory="" then temporaryDirectory=directory()
  sequence=0
  acceptedFrames=0
  acceptedBytes=0
  ended=.false
::attribute recognitionStream get
::attribute acceptedFrames get
::attribute acceptedBytes get
::attribute ended get
::method audioFrame
  expose recognitionStream temporaryDirectory sequence acceptedFrames acceptedBytes ended
  use strict arg frame
  if ended then return .false
  if frame==.nil then return .false
  format=.SpeechAudioFormat~new(frame~sampleRate,frame~channels,frame~sampleFormat,"PCM")
  sequence+=1
  path=SysTempFileName(temporaryDirectory||"/sip-speech-in-??????.pcm")
  if path="" then raise syntax 88.900 array("could not allocate temporary PCM path")
  bytes=frame~data
  written=charout(path,bytes,1)
  closeResult=stream(path,"C","CLOSE")
  if written<>0 then do
    deleteResult=SysFileDelete(path)
    raise syntax 88.900 array("could not write temporary PCM frame")
  end
  metadata=.Directory~new
  metadata["bridge"]="sip.speech.bridge/0.1"
  metadata["direction"]="IN"
  chunk=.SpeechAudioChunk~new("DATA",sequence,path,bytes~length,format,"sip-rtp",metadata)
  signal on syntax name pushFailed
  accepted=recognitionStream~pushChunk(chunk)
  signal off syntax
  deleteResult=SysFileDelete(path)
  if \accepted then raise syntax 88.900 array("recognition stream rejected SIP PCM frame")
  acceptedFrames+=1
  acceptedBytes+=bytes~length
  return .true
pushFailed:
  say "SIP speech recognition adapter failure rc=" rc "sigl=" sigl "condition=" condition("C") "description=" condition("D")
  deleteResult=SysFileDelete(path)
  signal off syntax
  raise propagate
::method endInput
  expose recognitionStream ended
  if ended then return .false
  ended=.true
  return recognitionStream~endInput

/* Pull-side adapter for SipOutboundAudio~attachProducer().  Streaming TTS
 * remains Speech-owned.  This adapter reads Speech's temporary PCM chunk,
 * releases it through the Speech stream, and yields RTP-sized PCM frames.
 * It performs no clocking; the caller pumping SipOutboundAudio remains the
 * pacing authority.
 */
::class SipSpeechSynthesisProducer public
::method init
  expose synthesisStream payloadType frameSamples frameBytes pending ended closed producedFrames producedBytes
  use strict arg synthesisStream, payloadType=0, frameSamples=160
  if synthesisStream==.nil then raise syntax 88.900 array("synthesis stream required")
  if payloadType<>0 then if payloadType<>8 then raise syntax 88.900 array("SIP speech producer supports RTP payload 0 or 8")
  if \datatype(frameSamples,"W") then raise syntax 88.900 array("frameSamples must be whole number")
  if frameSamples<1 then raise syntax 88.900 array("frameSamples must be positive")
  frameBytes=frameSamples*2
  pending=""
  ended=.false
  closed=.false
  producedFrames=0
  producedBytes=0
::attribute synthesisStream get
::attribute payloadType get
::attribute frameSamples get
::attribute ended get
::attribute closed get
::attribute producedFrames get
::attribute producedBytes get
::method nextAudioFrame
  expose synthesisStream payloadType frameSamples frameBytes pending ended closed producedFrames producedBytes
  use strict arg timeoutMs=1000
  if closed then return .nil
  do while pending~length<frameBytes
    if ended then leave
    chunk=synthesisStream~nextChunk(timeoutMs)
    if chunk==.nil then leave
    if chunk~isEnd then do
      ended=.true
      leave
    end
    self~requireTelephonyPcm(chunk~audioFormat)
    bytes=self~readChunk(chunk)
    released=synthesisStream~releaseChunk(chunk)
    pending=pending||bytes
  end
  if pending="" then return .nil
  if pending~length<frameBytes then do
    if \ended then return .nil
  end
  take=frameBytes
  if pending~length<take then take=pending~length
  bytes=pending~left(take)
  pending=pending~substr(take+1)
  producedFrames+=1
  producedBytes+=bytes~length
  return .RtpAudioFrame~new(bytes,8000,1,"S16LE",payloadType,bytes~length%2)
::method close
  expose closed
  if closed then return .false
  closed=.true
  return .true
::method readChunk
  use strict arg chunk
  path=chunk~ref
  size=stream(path,"C","QUERY SIZE")
  if \datatype(size,"W") then raise syntax 88.900 array("Speech PCM chunk size unavailable")
  bytes=charin(path,1,size)
  closeResult=stream(path,"C","CLOSE")
  if chunk~byteCount>0 then if bytes~length<>chunk~byteCount then raise syntax 88.900 array("Speech PCM chunk byte count mismatch")
  return bytes
::method requireTelephonyPcm
  use strict arg format
  if format==.nil then raise syntax 88.900 array("Speech PCM format required")
  if format~sampleRate<>8000 then raise syntax 88.900 array("Speech TTS must use telephony-8k for this RTP slice")
  if format~channels<>1 then raise syntax 88.900 array("Speech TTS must be mono for this RTP slice")
  if translate(format~sampleFormat)<>"S16LE" then raise syntax 88.900 array("Speech TTS must be S16LE for this RTP slice")
  return .true

::requires "SpeechCore.cls"
::requires "rtp.cls"
::requires "rexxutil" LIBRARY