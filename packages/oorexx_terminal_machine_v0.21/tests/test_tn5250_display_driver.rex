failures = 0
cp = .CodePage037~new
model = .PresentationSpace5250~new
session = .TerminalSession~new("TN5250-DRIVER", model)
watch = .TerminalWatchAlong~new(8)
session~addWatcher(watch)
driver = .TN5250DisplayDriver~new(model, session, cp)

/* RFC 1205 query flow: PUT/GET carrying ESC F3 Query -> NOP Query Reply. */
queryRecord = .TN5250RecordCodec~encode(.TN5250Opcode~PUT_GET, "04F30005D97000"x)
call assertTrue queryRecord~ok, "build query record"
handled = driver~consumeRecordBytes(queryRecord~value)
call assertTrue handled~ok, "consume query record"
call assertEq handled~value~commandName, "5250_QUERY", "query command"
call assertEq handled~value~outboundRecords~items, 1, "one query reply record"
replyBytes = handled~value~outboundRecords[1]
call assertEq replyBytes~left(10)~c2x, "004712A0000004000000", "RFC1205 query reply header"
replyRecord = .TN5250RecordCodec~decode(replyBytes)
call assertTrue replyRecord~ok, "decode query reply record"
call assertEq replyRecord~value~opcode~c2x, "00", "query reply NOP opcode"
call assertEq replyRecord~value~payload~length, 61, "query reply payload length"
call assertEq model~generation, 0, "query does not mutate screen generation"

/* OUTPUT ONLY carrying WTD commits one immutable generation to WatchAlong. */
wtd = "0411"x || "0008"x || "11"x || d2c(2) || d2c(6) || cp~encode("PUB400") ||,
      "11"x || d2c(10) || d2c(19) || "1D400020000A"x || "13"x || d2c(10) || d2c(20)
record = .TN5250RecordCodec~encode(.TN5250Opcode~OUTPUT_ONLY, wtd)
handled = driver~consumeRecordBytes(record~value)
call assertTrue handled~ok, "consume WTD record"
call assertTrue handled~value~changed, "WTD changed presentation"
call assertEq handled~value~snapshot~generation, 1, "WTD generation"
call assertEq watch~current~generation, 1, "WatchAlong commit"
call assertTrue pos("PUB400", watch~current~visibleText) > 0, "WatchAlong sees host text"
call assertTrue watch~current~field("F0740") \== .nil, "WatchAlong sees structured input field"

/* RFC message-light opcode is state too and therefore gets its own generation. */
light = .TN5250RecordCodec~encode(.TN5250Opcode~MESSAGE_LIGHT_ON)
handled = driver~consumeRecordBytes(light~value)
call assertTrue handled~ok, "message light record"
call assertEq handled~value~snapshot~generation, 2, "message light generation"
call assertTrue handled~value~snapshot~metadata["messageWaiting"], "message light in snapshot metadata"

/* Malformed WTD fails, but any already-applied prefix is committed as evidence. */
badWtd = "0411"x || "0000"x || "11"x || d2c(4) || d2c(1) || cp~encode("OK") || "06"x
badRecord = .TN5250RecordCodec~encode(.TN5250Opcode~OUTPUT_ONLY, badWtd)
handled = driver~consumeRecordBytes(badRecord~value)
call assertTrue \handled~ok, "malformed WTD rejected"
call assertEq handled~code, "5250_WTD_ORDER_UNKNOWN", "malformed WTD code"
call assertEq model~generation, 3, "partial host state committed as evidence"
call assertTrue pos("OK", watch~current~visibleText) > 0, "prefix mutation visible in watch evidence"
call assertTrue watch~current~metadata["lastDataStreamError"] \== .nil, "protocol error metadata preserved"

if failures > 0 then do
  say "FAIL test_tn5250_display_driver" failures
  exit 1
end
say "PASS test_tn5250_display_driver"
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
