chunks = .array~new
chunks~append("* 1 FETCH (UID 42 BODY[] {12}" || "0d0a"x || "hello ")
chunks~append("world!" || ")" || "0d0a"x || "A000001 OK fetch done" || "0d0a"x)
t = .ImapScriptedTransport~new(chunks)
cfg = .ImapReaderConfig~new; cfg~readChunkSize = 256; cfg~maxInlineLiteralBytes = 1024
r = .ImapWireReader~new(t, cfg)
rec = r~nextRecord
call assert rec~classification = "UNTAGGED", "untagged classification"
call assert rec~literalCount = 1, "one literal"
call assert rec~literalSegments[1]~announcedLength = 12, "literal announced length"
call assert rec~literalSegments[1]~bytes = "hello world!", "literal exact bytes"
call assert rec~lineSegments[2] = ")", "post-literal tail"
tagged = r~nextRecord
call assert tagged~tag = "A000001", "tagged completion"
call assert tagged~completionStatus = "OK", "completion status"

/* A large literal is consumed without retaining bytes by default. */
chunks2 = .array~of("* 2 FETCH (UID 43 BODY[] {20}" || "0d0a"x || "01234567890123456789)" || "0d0a"x)
t2 = .ImapScriptedTransport~new(chunks2)
cfg2 = .ImapReaderConfig~new; cfg2~maxInlineLiteralBytes = 4
r2 = .ImapWireReader~new(t2, cfg2)
rec2 = r2~nextRecord
call assert rec2~literalSegments[1]~kind = "DISCARDED", "large literal bounded"
call assert rec2~literalSegments[1]~storedLength = 20, "large literal fully consumed"
call assert rec2~literalSegments[1]~bytes = "", "large literal not retained"

say "PASS test_wire_reader"
exit 0
assert: procedure
  use strict arg condition, message
  if \condition then do; say "FAIL:" message; exit 1; end
  return

::requires "ImapCore.cls"
::requires "TestSupport.cls"
