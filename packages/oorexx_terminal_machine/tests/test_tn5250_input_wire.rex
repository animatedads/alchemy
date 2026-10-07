failures = 0
cp = .CodePage037~new
model = .PresentationSpace5250~new
session = .TerminalSession~new("INPUT-WIRE", model)
watch = .TerminalWatchAlong~new(8)
session~addWatcher(watch)
driver = .TN5250DisplayDriver~new(model, session, cp)
agent = .Terminal5250AgentPort~new(session, model)

/* One RFC record can carry WTD followed by READ MDT.  The WTD parser must not
 * mistake the second ESC command for display data. */
chain = "0411"x || "0008"x ||,
        "11"x || d2c(2) || d2c(5) || cp~encode("SIGN ON") ||,
        "11"x || d2c(10) || d2c(19) || "1D400020000A"x ||,
        "11"x || d2c(11) || d2c(19) || "1D400027000A"x ||,
        "13"x || d2c(10) || d2c(20) ||,
        "04520000"x
record = .TN5250RecordCodec~encode(.TN5250Opcode~PUT_GET, chain)
handled = driver~consumeRecordBytes(record~value)
call assertTrue handled~ok, "WTD+READ chain"
call assertEq handled~value~commandName, "WRITE_TO_DISPLAY+READ_MDT", "chain command names"
call assertEq model~pendingReadKind, "READ_MDT", "read pending"
call assertEq watch~current~generation, 1, "chain committed once"

/* AI modifies normal and nondisplay fields, then presses Enter. */
g = agent~snapshot~generation
call assertTrue agent~setField(g, "F0740", "FRED")~ok, "set user"
call assertTrue agent~setField(g, "F0820", "S3CRET")~ok, "set password"
pressed = agent~press(g, "ENTER")
call assertTrue pressed~ok, "press enter"
call assertEq pressed~value~aidName, "ENTER", "safe AID receipt"
call assertEq agent~snapshot~field("F0820")~value, "<SECRET>", "AI still cannot read password"

/* Driver turns the internal read object into the RFC1205 NOP client record. */
outbound = driver~takePendingInputRecord
call assertTrue outbound~ok, "build input record"
decoded = .TN5250RecordCodec~decode(outbound~value)
call assertTrue decoded~ok, "decode built input record"
call assertEq decoded~value~opcode~c2x, "00", "input NOP opcode"
payload = decoded~value~payload
call assertEq payload~substr(1,3)~c2x, "0A14F1", "cursor row/col + Enter AID"
/* Field 1: SBA row10 col20 + FRED, Field 2: SBA row11 col20 + secret. */
expected = "11"x || d2c(10) || d2c(20) || cp~encode("FRED") ||,
           "11"x || d2c(11) || d2c(20) || cp~encode("S3CRET")
call assertEq payload~substr(4)~c2x, expected~c2x, "MDT field stream"
call assertTrue pos("S3CRET", watch~current~visibleText) = 0, "secret absent from WatchAlong text"
call assertEq watch~current~field("F0820")~value, "<SECRET>", "secret absent from WatchAlong fields"

/* Telnet framing performs IAC byte doubling after RFC logical length is fixed. */
frame = .TN5250RecordCodec~telnetFrame(outbound~value)
call assertEq frame~right(2)~c2x, "FFEF", "input record ends IAC EOR"

if failures > 0 then do
  say "FAIL test_tn5250_input_wire" failures
  exit 1
end
say "PASS test_tn5250_input_wire"
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

::requires "TN5250DisplayDriver.cls"
