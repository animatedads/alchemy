failures = 0
cp = .CodePage037~new
runtime = .TN5250RuntimeSession~new("VERTICAL", "IBM-3179-2", "AIBOT01")
client = runtime~automationPort

/* Server-driven Telnet negotiation.  This is transport-free but byte-for-byte
 * network framing: one object owns the incremental Telnet state machine. */
neg = .TelnetByte~IAC || .TelnetByte~DO || .TelnetOption~TERMINAL_TYPE ||,
      .TelnetByte~IAC || .TelnetByte~SB || .TelnetOption~TERMINAL_TYPE || .TelnetTerminalType~SEND || .TelnetByte~IAC || .TelnetByte~SE ||,
      .TelnetByte~IAC || .TelnetByte~DO || .TelnetOption~EOR ||,
      .TelnetByte~IAC || .TelnetByte~WILL || .TelnetOption~EOR ||,
      .TelnetByte~IAC || .TelnetByte~DO || .TelnetOption~BINARY ||,
      .TelnetByte~IAC || .TelnetByte~WILL || .TelnetOption~BINARY
n = runtime~feedNetwork(neg)
call assertTrue n~ok, "Telnet negotiation feed"
call assertTrue runtime~transparentReady, "transparent mode ready"
call assertTrue n~value~outboundBytes~length > 0, "negotiation replies emitted"
/* The AI-facing composed object must not expose trusted raw-state objects. */
call assertTrue \client~hasMethod("MODEL"), "automation facade has no mutable model getter"
call assertTrue \client~hasMethod("DRIVER"), "automation facade has no raw driver getter"
call assertTrue \client~hasMethod("TELNET"), "automation facade has no raw Telnet getter"
call assertTrue \client~hasMethod("FEEDNETWORK"), "automation facade has no network feed"
call assertTrue \client~hasMethod("DRAINOUTBOUND"), "automation facade has no raw outbound drain"
call assertTrue \client~hasMethod("RUNTIME"), "automation facade has no runtime getter"

/* A real host record: WTD + READ MDT. */
wtd = "0411"x || "0008"x ||,
      "11"x || d2c(2) || d2c(5) || cp~encode("PUB400 SIGN ON") ||,
      "11"x || d2c(10) || d2c(19) || "1D400020000A"x ||,
      "11"x || d2c(11) || d2c(19) || "1D400027000A"x ||,
      "13"x || d2c(10) || d2c(20) ||,
      "04520000"x
hostRecord = .TN5250RecordCodec~encode(.TN5250Opcode~PUT_GET, wtd)
call assertTrue hostRecord~ok, "host record build"
hostFrame = .TN5250RecordCodec~telnetFrame(hostRecord~value)
/* Split the frame to prove incremental network feeding. */
a = hostFrame~left(7)
b = hostFrame~substr(8)
part = runtime~feedNetwork(a)
call assertTrue part~ok, "partial frame feed"
call assertEq part~value~driverResults~items, 0, "no record before EOR"
full = runtime~feedNetwork(b)
call assertTrue full~ok, "complete frame feed"
call assertEq full~value~driverResults~items, 1, "one host record dispatched"
call assertTrue pos("PUB400 SIGN ON", client~watchAlong~current~visibleText) > 0, "WatchAlong native screen"
call assertEq client~snapshot~metadata["pendingRead"], "READ_MDT", "host READ pending"

/* AI uses structured fields; the resulting output is already a Telnet frame. */
g = client~snapshot~generation
call assertTrue client~setField(g, "F0740", "FRED")~ok, "AI user field"
call assertTrue client~setField(g, "F0820", "SECRET")~ok, "AI password field"
action = client~press(g, "ENTER")
call assertTrue action~ok, "AI Enter"
call assertTrue action~value~transportOutputPending, "AID reports trusted transport output pending"
call assertTrue \action~value~hasMethod("OUTBOUNDBYTES"), "safe action result has no raw wire getter"
wireResult = runtime~drainTerminalOutput
call assertTrue wireResult~ok, "trusted runtime drains AID output"
wireBytes = wireResult~value
call assertTrue wireBytes~length > 0, "trusted runtime has framed network output"
call assertEq action~value~snapshot~field("F0820")~value, "<SECRET>", "AI action result remains redacted"

/* Parse our emitted frame from the peer side and verify RFC1205 + 5250 input. */
peerProfile = .TN5250TelnetProfile~new
peer = .TelnetMachine~new(peerProfile)
peer~feed(wireBytes)
events = peer~drainEvents
call assertEq events~items, 1, "peer sees one record"
call assertEq events[1]~eventType, "RECORD", "peer record event"
inRecord = .TN5250RecordCodec~decode(events[1]~data)
call assertTrue inRecord~ok, "peer RFC1205 decode"
call assertEq inRecord~value~opcode~c2x, "00", "client input uses NOP opcode"
call assertEq inRecord~value~payload~substr(1,3)~c2x, "0A14F1", "cursor + Enter AID"
call assertTrue pos(cp~encode("SECRET"), inRecord~value~payload) > 0, "secret exists only on outbound wire"
call assertTrue pos("SECRET", client~watchAlong~current~visibleText) = 0, "secret absent from WatchAlong"

/* Reverse timing: AID first, READ later.  No network response is emitted until
 * the READ arrives, matching IBM's pending-AID keyboard semantics. */
lateRuntime = .TN5250RuntimeSession~new("LATE-READ")
late = lateRuntime~automationPort
lateWtd = "0411"x || "0008"x || "11"x || d2c(8) || d2c(10) || "1D4000200008"x
lateRec = .TN5250RecordCodec~encode(.TN5250Opcode~OUTPUT_ONLY, lateWtd)
call assertTrue lateRec~ok, "late WTD record"
call assertTrue lateRuntime~feedNetwork(.TN5250RecordCodec~telnetFrame(lateRec~value))~ok, "late WTD feed"
lg = late~snapshot~generation
call assertTrue late~setField(lg, "F0571", "COMMAND")~ok, "late field input"
lateAction = late~press(lg, "ENTER")
call assertTrue lateAction~ok, "late Enter accepted"
call assertTrue \lateAction~value~transportOutputPending, "AID retained without READ produces no output"
call assertEq late~snapshot~metadata["pendingAid"], "ENTER", "pending AID visible as protocol state"
readRec = .TN5250RecordCodec~encode(.TN5250Opcode~INVITE, "04520000"x)
readFeed = lateRuntime~feedNetwork(.TN5250RecordCodec~telnetFrame(readRec~value))
call assertTrue readFeed~ok, "late READ feed"
call assertTrue readFeed~value~outboundBytes~length > 0, "late READ services retained AID"
call assertEq late~snapshot~metadata["pendingAid"], "", "retained AID cleared after service"

if failures > 0 then do
  say "FAIL test_tn5250_vertical" failures
  exit 1
end
say "PASS test_tn5250_vertical"
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
