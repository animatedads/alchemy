call = .SipCall~new(0, "probe-call", "127.0.0.1", 5060, 40000, 41000, 0)
control = call~control
input = call~audioIn
output = call~audioOut
receiver = call~rtpReceiver
sender = call~rtpSender

say "INITIAL" control~state input~state output~state receiver~state sender~state

input~start
say "INPUT_ONLY" control~state input~state output~state receiver~state sender~state
if input~state <> "RUNNING" then exit 10
if receiver~state <> "CREATED" then exit 11

receiver~start
say "RX_STARTED" control~state input~state output~state receiver~state sender~state
if receiver~state <> "RUNNING" then exit 12

input~stop
say "INPUT_STOPPED" control~state input~state output~state receiver~state sender~state
if receiver~state <> "RUNNING" then exit 13

output~start
if sender~state <> "CREATED" then exit 14
sender~start
output~stop
say "OUTPUT_STOPPED" control~state input~state output~state receiver~state sender~state
if sender~state <> "RUNNING" then exit 15

handler = .ProbeControlHandler~new
control~attachHandler("APP", handler)
control~start
control~pause
control~resume
control~remoteEnded
say "CONTROL_EVENTS" handler~count handler~events
say "HANDLER_ERROR" control~handlerError("APP")
if handler~count <> 4 then exit 16
if control~state <> "STOPPED" then exit 17
if input~state <> "STOPPED" then exit 18
if receiver~state <> "RUNNING" then exit 19
if sender~state <> "RUNNING" then exit 20

bad = .BrokenControlHandler~new
control~attachHandler("BROKEN", bad)
control~start
say "BROKEN_ERROR_PRESENT" (control~handlerError("BROKEN") <> "")
if control~handlerError("BROKEN") = "" then exit 21
if handler~count <> 5 then exit 22
if receiver~state <> "RUNNING" then exit 23
if sender~state <> "RUNNING" then exit 24

say "PASS peer lifecycle isolation"
exit 0

::class ProbeControlHandler
::method init
  expose count events
  count = 0
  events = ""
::attribute count get
::attribute events get
::method controlEvent
  expose count events
  use strict arg event
  count += 1
  if events = "" then events = event~type
  else events ||= "," || event~type

::class BrokenControlHandler
::method controlEvent
  use strict arg event
  raise syntax 98.900 array("deliberate control handler failure")

::requires "sip.cls"
