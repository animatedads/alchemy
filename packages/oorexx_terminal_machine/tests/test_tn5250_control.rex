failures = 0
runtime = .TN5250RuntimeSession~new("CONTROL")
auto = runtime~automationPort

g = auto~snapshot~generation
request = auto~systemRequest(g)
call assertTrue request~ok, "safe System Request accepted"
call assertTrue request~value~transportOutputPending, "System Request reports output pending"
call assertTrue \request~value~hasMethod("OUTBOUNDBYTES"), "System Request result has no raw bytes"
wire = runtime~drainTerminalOutput
call assertTrue wire~ok, "trusted runtime drains System Request"

peer = .TelnetMachine~new(.TN5250TelnetProfile~new)
peer~feed(wire~value)
events = peer~drainEvents
call assertEq events~items, 1, "one System Request record"
rec = .TN5250RecordCodec~decode(events[1]~data)
call assertTrue rec~ok, "System Request RFC record"
call assertEq rec~value~opcode~c2x, "00", "System Request opcode NOP"
call assertEq rec~value~flags~c2x, "0400", "RFC1205 SRQ flag"

/* RFC 1205 Cancel Invite flow requires a client echo. */
cancel = .TN5250RecordCodec~encode(.TN5250Opcode~CANCEL_INVITE)
reply = runtime~feedNetwork(.TN5250RecordCodec~telnetFrame(cancel~value))
call assertTrue reply~ok, "server Cancel Invite accepted"
call assertTrue reply~value~outboundBytes~length > 0, "Cancel Invite echoed"
peer2 = .TelnetMachine~new(.TN5250TelnetProfile~new)
peer2~feed(reply~value~outboundBytes)
ev2 = peer2~drainEvents
call assertEq ev2~items, 1, "one Cancel Invite echo"
echo = .TN5250RecordCodec~decode(ev2[1]~data)
call assertTrue echo~ok, "Cancel Invite echo decodes"
call assertEq echo~value~opcode~c2x, "0A", "Cancel Invite echo opcode"
call assertEq echo~value~payload~length, 0, "Cancel Invite echo no payload"

if failures > 0 then do
  say "FAIL test_tn5250_control" failures
  exit 1
end
say "PASS test_tn5250_control"
exit 0

assertEq: procedure expose failures
  use arg actual, expected, label
  if actual == expected then return
  failures += 1
  say "ASSERT_EQ FAIL:" label "expected="expected "actual="actual
  return
assertTrue: procedure expose failures
  use arg condition, label
  if condition then return
  failures += 1
  say "ASSERT_TRUE FAIL:" label
  return

::requires "TN5250Automation.cls"
