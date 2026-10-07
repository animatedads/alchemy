server = .SipServer~new("127.0.0.1", 5099)
say "READY" server~port
event = server~poll(5)
if event[1] <> "invite" then do
  say "FAIL EVENT" event[1]
  server~close
  exit 2
end
call = server~call(event[2])
input = call~audioIn
output = call~audioOut
receiver = input~receiver
sender = output~sender
say "OBJECTS" call~control~class~id input~class~id output~class~id receiver~class~id sender~class~id
say "IDENTITY" (receiver == input) (sender == output) (receiver == sender)

stt = .CountingConsumer~new("STT")
recorder = .CountingConsumer~new("RECORDER")
broken = .FailingConsumer~new
input~attachConsumer("STT", stt)
input~attachConsumer("RECORDER", recorder)
input~attachConsumer("BROKEN", broken)

input~start
receiver~start
output~start
sender~start
frame = input~receiveFrame(2000, 1600)
if frame == .nil then do
  say "FAIL NO_FRAME"
  server~close
  exit 3
end
say "FRAME" frame~bytes frame~sampleCount frame~sampleRate frame~sampleFormat frame~payloadType frame~sequence frame~timestamp frame~ssrc frame~marker frame~sourceAddress frame~sourcePort
say "CONSUMERS" stt~count recorder~count input~consumerNames~items
say "BROKEN_ERROR_PRESENT" (input~consumerError("BROKEN") <> "")
say "IN_STATES" input~state receiver~state

pcm = "0000"x~copies(160)
tts = .FixedProducer~new("TTS", pcm)
mic = .FixedProducer~new("MIC", pcm)
output~attachProducer("TTS", tts)
output~attachProducer("MIC", mic)
say "PRODUCERS" output~producerNames~items output~activeProducer
first = output~pumpProducer
output~selectProducer("MIC")
second = output~pumpProducer
say "SEND1" first~sampleCount first~sequence first~timestamp first~payloadType first~packetBytes
say "SEND2" second~sampleCount second~sequence second~timestamp second~payloadType second~packetBytes
say "ACTIVE" output~activeProducer
say "PRODUCER_COUNTS" tts~count mic~count

receiver~stop
say "AFTER_RX_STOP" call~control~state input~state receiver~state output~state sender~state
output~stop
say "AFTER_OUT_STOP" call~control~state input~state receiver~state output~state sender~state
server~close

::class CountingConsumer
::method init
  expose name count lastFrame
  use strict arg name
  count = 0
  lastFrame = .nil
::attribute count get
::attribute lastFrame get
::method audioFrame
  expose count lastFrame
  use strict arg frame
  count += 1
  lastFrame = frame

::class FailingConsumer
::method audioFrame
  use strict arg frame
  raise syntax 98.900 array("deliberate consumer failure")

::class FixedProducer
::method init
  expose name pcm count
  use strict arg name, pcm
  count = 0
::attribute count get
::method nextAudioFrame
  expose pcm count
  count += 1
  return .RtpAudioFrame~new(pcm, 8000, 1, "S16LE", 0, pcm~length % 2)

::requires "sip.cls"
