crlf = "0d0a"x
chunks = .array~of("* SEARCH " || "1 "~copies(2000))
t = .ImapScriptedTransport~new(chunks)
cfg = .ImapReaderConfig~new; cfg~maxLineBytes = 1024; cfg~readChunkSize = 256
r = .ImapWireReader~new(t, cfg)
signal on syntax name expected
ignored = r~nextRecord
signal off syntax
say "FAIL: oversized line accepted"
exit 1
expected:
  signal off syntax
  if condition("A")[1] <> "IMAP_LINE_TOO_LARGE" then do; say "FAIL: wrong line bound error" condition("A")[1]; exit 1; end
say "PASS test_line_bound"
exit 0

::requires "ImapCore.cls"
::requires "TestSupport.cls"
