call addPath
call testUidSet
call testCapabilities
call testCodec
call testSyncPlanner
say "PASS test_core"
exit 0

addPath:
  return

testUidSet:
  s = .ImapUidSet~parse("1:1000000,2000000,3000000:3000010")
  call assert s~count = 1000012, "compact UID count"
  call assert s~contains(999999), "range contains"
  call assert \s~contains(1500000), "range excludes"
  signal on syntax name expectedLimit
  ignored = s~toArray(1000)
  signal off syntax
  call fail "large UID set unexpectedly materialized"
expectedLimit:
  signal off syntax
  call assert condition("A")[1] = "UID_SET_MATERIALIZE_LIMIT", "materialize limit raised"
  return

testCapabilities:
  c = .ImapCapabilities~fromCapabilityLine("* CAPABILITY IMAP4rev1 UIDPLUS MOVE CONDSTORE QRESYNC ESEARCH LITERAL+ AUTH=PLAIN")
  call assert c~has("move"), "capability case-insensitive"
  call assert c~has("QRESYNC"), "qresync"
  call assert c~hasPrefix("AUTH="), "auth prefix"
  return

testCodec:
  q = .ImapCodec~quoteString('a"b\c')
  call assert q = '"a\"b\\c"', "quoted string escaping"
  return

testSyncPlanner:
  caps = .ImapCapabilities~new~add("QRESYNC")~add("CONDSTORE")
  prev = .ImapMailboxState~new; prev~uidValidity = "77"; prev~highestModSeq = "9001"
  curr = prev~copy
  p = .ImapSyncPlanner~plan(caps, prev, curr, "500")
  call assert p~strategy = "QRESYNC", "QRESYNC preferred"
  curr~uidValidity = "78"
  p = .ImapSyncPlanner~plan(caps, prev, curr, "500")
  call assert p~strategy = "REBUILD_REQUIRED", "UIDVALIDITY change fails closed"
  return

assert: procedure
  use strict arg condition, message
  if \condition then call fail message
  return
fail: procedure
  use strict arg message
  say "FAIL:" message
  exit 1

::requires "ImapCore.cls"
