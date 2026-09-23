parse arg outFile
if outFile = "" then do; say "usage: test_storage_adapter.rex OUTFILE"; exit 2; end
crlf = "0d0a"x
payload = "Subject: stored" || crlf || crlf || "large-ish body"
chunks = .array~of("* 7 FETCH (UID 99 BODY[] {" || payload~length || "}" || crlf || payload || ")" || crlf)
t = .ImapScriptedTransport~new(chunks)
provider = .TestStorageSinkProvider~new(outFile)
factory = .ImapStorageLiteralSinkFactory~new(provider)
cfg = .ImapReaderConfig~new; cfg~maxInlineLiteralBytes = 1
r = .ImapWireReader~new(t, cfg)
rec = r~nextRecord(factory)
call assert rec~literalSegments[1]~kind = "STORAGE_FABRIC", "storage sink selected"
call assert rec~literalSegments[1]~bytes = "", "payload not retained inline"
readBack = charin(outFile, 1, payload~length)
call stream outFile, "c", "close"
call assert readBack = payload, "storage sink exact payload"
say "PASS test_storage_adapter"
exit 0

assert: procedure
  use strict arg condition, message
  if \condition then do; say "FAIL:" message; exit 1; end
  return

::class TestStorageSinkProvider public
::method init
  expose path
  use strict arg p
  path = p
::method createStorageSink
  expose path
  use strict arg length, record
  return .StorageLocalFileByteSink~new(path)

::requires "ImapStorageFabricAdapter.cls"
::requires "TestSupport.cls"
