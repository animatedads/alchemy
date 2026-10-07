server = .SipServer~new("127.0.0.1", 5098)
say "READY" server~port
event = server~poll(5)
if event[1] <> "invite" then do
  say "FAIL EVENT" event[1]
  server~close
  exit 2
end
callId = event[2]
call = server~call(callId)
if call == .nil then do
  say "FAIL NO_CALL"
  server~close
  exit 3
end
say "CALL" call~callId
say "CONTROL_CLASS" call~control~class~id
say "IN_CLASS" call~audioIn~class~id
say "OUT_CLASS" call~audioOut~class~id
say "IDENTITIES" (call~control == call~audioIn) (call~audioIn == call~audioOut) (call~control == call~audioOut)
say "STATES0" call~control~state call~audioIn~state call~audioOut~state
call~control~start
call~audioIn~start
call~audioOut~start
call~rtpReceiver~start
call~rtpSender~start
say "STATES1" call~control~state call~audioIn~state call~audioOut~state
pcm = "0000"x~copies(160)
samples = call~audioOut~sendPcm(pcm)
say "SENT_SAMPLES" samples
call~audioIn~stop
say "STATES2" call~control~state call~audioIn~state call~audioOut~state
server~close
::requires "sip.cls"
