assertions = 0
framer = .QueueSocketFramer~new(32)
writer = .PartialConnection~new("", 3)
sent = framer~sendFrame(writer, "abcdef")
call assertOk sent, "partial writes are completed"
call assertEqual "00000006abcdef", writer~written, "frame has 8-byte hex length prefix"
reader = .PartialConnection~new(writer~written, 99)
received = framer~receiveFrame(reader)
call assertOk received, "framed payload received"
call assertEqual "abcdef", received~value, "framed payload preserved"
large = framer~sendFrame(.PartialConnection~new("", 99), "x"~copies(33))
call assertEqual "FRAME_TOO_LARGE", large~code, "oversize frame rejected"
bad = framer~receiveFrame(.PartialConnection~new("zzzzzzzz", 99))
call assertEqual "FRAME_HEADER_INVALID", bad~code, "non-hex header rejected"
say "OBJECT QUEUE FABRIC V0.8 SOCKET FRAMER: OK"
say "assertions=" || assertions
exit 0

assertOk: procedure expose assertions
  use arg operationResult, label
  assertions += 1
  if \operationResult~ok then do
    say "ASSERT FAILED:" label "code=" operationResult~code "detail=" operationResult~detail
    exit 1
  end
  return

assertEqual: procedure expose assertions
  use arg expected, actual, label
  assertions += 1
  if expected \== actual then do
    say "ASSERT FAILED:" label "expected=" expected "actual=" actual
    exit 1
  end
  return

::class PartialConnection
::attribute written get
::attribute description get
::method init
  expose input written maxWrite description
  use strict arg input = "", maxWrite = 99
  written = ""
  description = "READY:"
::method charOut
  expose written maxWrite
  use strict arg bytes, start = 0
  count = bytes~length~min(maxWrite)
  written ||= bytes~substr(1, count)
  return count
::method charIn
  expose input
  use strict arg start = 0, count = 1
  if input~length = 0 then return ""
  actual = count~min(input~length)
  bytes = input~substr(1, actual)
  input = input~substr(actual + 1)
  return bytes

::requires "ObjectQueueSocketTransport.cls"
