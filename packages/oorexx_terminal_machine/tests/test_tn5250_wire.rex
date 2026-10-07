failures = 0

/* RFC 1205 section 3 turn-message-light-on example, excluding IAC EOR. */
rfcRecord = "000A12A000000400000B"x
decoded = .TN5250RecordCodec~decode(rfcRecord)
call assertTrue decoded~ok, "decode RFC record"
call assertEq decoded~value~logicalLength, 10, "logical length"
call assertEq decoded~value~recordType~c2x, "12A0", "record type"
call assertEq decoded~value~variableHeaderLength, 4, "variable header"
call assertEq decoded~value~opcode~c2x, "0B", "message light opcode"

encoded = .TN5250RecordCodec~encode(.TN5250Opcode~MESSAGE_LIGHT_ON)
call assertTrue encoded~ok, "encode record"
call assertEq encoded~value~c2x, rfcRecord~c2x, "RFC exact encoding"
call assertEq .TN5250RecordCodec~telnetFrame(encoded~value)~c2x, "000A12A000000400000BFFEF", "RFC EOR frame"

/* Incremental negotiation based on RFC 1205 sequence. */
profile = .TN5250TelnetProfile~new("IBM-3179-2", "AIBOT0001")
telnet = .TelnetMachine~new(profile)

telnet~feed("FFFD18"x) /* server DO TERMINAL-TYPE */
call assertEq telnet~drainOutbound~c2x, "FFFB18", "WILL terminal type"
telnet~feed("FFFA1801FFF0"x) /* SB TTYPE SEND */
call assertEq telnet~drainOutbound~c2x, ("FFFA1800"x || "IBM-3179-2" || "FFF0"x)~c2x, "terminal type IS"

telnet~feed("FFFD19"x) /* DO EOR */
call assertEq telnet~drainOutbound~c2x, "FFFB19", "WILL EOR"
telnet~feed("FFFB19"x) /* WILL EOR */
call assertEq telnet~drainOutbound~c2x, "FFFD19", "DO EOR"
telnet~feed("FFFD00"x) /* DO BINARY */
call assertEq telnet~drainOutbound~c2x, "FFFB00", "WILL BINARY"
telnet~feed("FFFB00"x) /* WILL BINARY */
call assertEq telnet~drainOutbound~c2x, "FFFD00", "DO BINARY"
call assertTrue profile~transparentReady, "transparent mode ready"

/* NEW-ENVIRON DEVNAME support before transparent mode completion. */
profile2 = .TN5250TelnetProfile~new("IBM-3179-2", "AIBOT0007")
telnet2 = .TelnetMachine~new(profile2)
telnet2~feed("FFFD27"x)
call assertEq telnet2~drainOutbound~c2x, "FFFB27", "WILL NEW-ENVIRON"
telnet2~feed("FFFA270103FFF0"x) /* SEND USERVAR */
envExpected = "FFFA2700"x || "03"x || "DEVNAME" || "01"x || "AIBOT0007" || "FFF0"x
call assertEq telnet2~drainOutbound~c2x, envExpected~c2x, "DEVNAME environment response"

/* IAC escaping inside a logical application record survives parsing. */
raw = "01FF02"x
framed = .TelnetCodec~frameRecord(raw)
call assertEq framed~c2x, "01FFFF02FFEF", "IAC doubled on send"
nullProfile = .TN5250TelnetProfile~new
tm = .TelnetMachine~new(nullProfile)
tm~feed(framed)
events = tm~drainEvents
call assertEq events~items, 1, "one EOR event"
call assertEq events[1]~eventType, "RECORD", "record event"
call assertEq events[1]~data~c2x, raw~c2x, "IAC restored on receive"

if failures > 0 then do
  say "FAIL test_tn5250_wire" failures
  exit 1
end
say "PASS test_tn5250_wire"
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

::requires "TN5250Wire.cls"
