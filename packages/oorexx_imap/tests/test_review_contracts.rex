numeric digits 9
call testResponseCopies
call testCommandResultCopies
call testUidSetCopiesAndPrecision
call testNestedUidResultCopies
call testSessionOwnershipCopies
call testIndexResultCopies
call testLiteralReadGuard
say "PASS test_review_contracts"
exit 0

testResponseCopies:
  rec = .ImapResponseRecord~new("* OK hello")
  lines = rec~lineSegments
  lines~append("MUTATION")
  call assert rec~lineCount = 1, "response lineSegments getter is defensive"
  sink = .ImapInlineLiteralSink~new
  ignore = sink~write("abc")
  rec~addLiteral(.ImapLiteralSegment~new(3, sink))
  literals = rec~literalSegments
  literals~append(.nil)
  call assert rec~literalCount = 1, "response literalSegments getter is defensive"
  return

testCommandResultCopies:
  original = .array~of(.ImapResponseRecord~new("* OK x"))
  cmdResult = .ImapCommandResult~new("A000001", "OK", "done", original, .array~new)
  original~append(.ImapResponseRecord~new("* OK y"))
  call assert cmdResult~untagged~items = 1, "command result copies constructor arrays"
  copy = cmdResult~untagged
  copy~append(.ImapResponseRecord~new("* OK z"))
  call assert cmdResult~untagged~items = 1, "command result getter is defensive"
  return

testUidSetCopiesAndPrecision:
  s = .ImapUidSet~parse("1696928003123:1696928003124")
  call assert s~count = 2, "large UID count survives caller DIGITS 9"
  value = s~uidAtOrdinal(2)
  call assert value~string = "1696928003124", "large UID ordinal remains exact"
  copy = s~ranges
  copy~append(.ImapUidRange~new(7))
  call assert s~rangeCount = 1, "UID range getter is defensive"
  return

testNestedUidResultCopies:
  source = .ImapUidSet~parse("1:3")
  appendResult = .ImapAppendResult~new(.ImapCommandResult~new("A1", "OK", "done"), "77", source)
  source~addUid(99)
  call assert appendResult~uidSet~count = 3, "append result copies UID set on construction"
  exposed = appendResult~uidSet
  exposed~addUid(100)
  call assert appendResult~uidSet~count = 3, "append result UID getter is defensive"

  search = .ImapSearchResult~new
  search~all = .ImapUidSet~parse("10:11")
  exposed = search~all
  exposed~addUid(12)
  call assert search~all~count = 2, "search result UID set getter is defensive"
  return

testSessionOwnershipCopies:
  crlf = "0d0a"x
  chunks = .array~new
  chunks~append("* OK [CAPABILITY IMAP4rev1 UIDPLUS] ready" || crlf)
  chunks~append("* FLAGS (\Seen)" || crlf ||,
                "* 2 EXISTS" || crlf ||,
                "* 0 RECENT" || crlf ||,
                "* OK [UIDVALIDITY 1696928003123] valid" || crlf ||,
                "* OK [UIDNEXT 1696928003124] next" || crlf ||,
                "A000001 OK [READ-ONLY] EXAMINE completed" || crlf)
  transport = .ImapScriptedTransport~new(chunks)
  session = .ImapSession~new(transport)
  ignore = session~acceptGreeting
  caps = session~capabilities
  caps~add("MOVE")
  call assert \session~capabilities~has("MOVE"), "session capability getter is defensive"
  ignore = session~examine("INBOX")
  selected = session~selectedState
  selected~uidValidity = "1"
  call assert session~selectedState~uidValidity = "1696928003123", "selected-state getter is defensive"
  return

testIndexResultCopies:
  termSource = .array~of("facebook")
  hitSource = .array~of(.ImapIndexRecord~new("acct", "INBOX", "1696928003123", "1696928003124", 1))
  idx = .ImapIndexSearchResult~new("facebook", termSource, hitSource)
  termSource~append("evil")
  hitSource~append(.ImapIndexRecord~new("acct", "INBOX", "1696928003123", "1696928003125", 1))
  call assert idx~terms~items = 1, "index result copies constructor term array"
  call assert idx~hits~items = 1, "index result copies constructor hit array"
  exposedTerms = idx~terms; exposedTerms~append("evil")
  exposedHits = idx~hits; exposedHits~empty
  call assert idx~terms~items = 1, "index result terms getter is defensive"
  call assert idx~hits~items = 1, "index result hits getter is defensive"
  return

testLiteralReadGuard:
  source = .ImapStringLiteralSource~new("abc")
  signal on syntax name expected
  ignored = source~read(0)
  signal off syntax
  call fail "zero literal read request unexpectedly accepted"
expected:
  if value("IMAP_CONDITION_DIAGNOSTICS",,"ENVIRONMENT") = "1" then say "expected condition" rc sigl condition("C") condition("D")
  signal off syntax
  call assert condition("A")[1] = "IMAP_LITERAL_READ_SIZE_INVALID", "literal read size fails closed"
  return

assert: procedure
  use strict arg condition, message
  if \condition then call fail message
  return
fail: procedure
  use strict arg message
  say "FAIL:" message
  exit 1

::requires "ImapSession.cls"
::requires "ImapIndexCore.cls"
::requires "TestSupport.cls"
