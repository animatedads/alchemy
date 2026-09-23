/* Intent-aware APPEND must block semantic mismatch before writing to wire. */
chunks = .array~new
chunks~append("+ ready" || "0d0a"x || "A000001 OK appended" || "0d0a"x)
transport = .ImapScriptedTransport~new(chunks)
session = .ImapSession~new(transport)

citadel = .ImapServerBehaviorProfile~citadel
/* Intentional submit to Citadel Sent is allowed. */
r = session~appendBytesWithIntent("Sent", "hello", citadel, "SENT", "SUBMIT")
call assertTrue r~ok, "Citadel submit result"
joined = ""
do w over transport~writes; joined = joined || w; end
call assertContains joined, 'APPEND "Sent" {5}', "APPEND sent command"
call assertContains joined, "hello", "literal written"

/* A restore into Citadel Sent must fail before any command is written. */
empty = .array~new
transport2 = .ImapScriptedTransport~new(empty)
session2 = .ImapSession~new(transport2)
signal on syntax name blocked
ignore = session2~appendBytesWithIntent("Sent", "archive", citadel, "SENT", "RESTORE")
signal off syntax
say "FAIL Citadel restore should have been blocked"
exit 1
blocked:
  signal off syntax
  call assertEq transport2~writes~items, 0, "blocked semantic mismatch writes nothing"

say "PASS test_append_intent"
exit 0

assertEq: procedure
  use strict arg actual, expected, label
  if actual \== expected then do
    say "FAIL" label "expected=" expected "actual=" actual
    exit 1
  end
  return
assertTrue: procedure
  use strict arg value, label
  if \value then do
    say "FAIL" label
    exit 1
  end
  return
assertContains: procedure
  use strict arg haystack, needle, label
  if haystack~pos(needle) = 0 then do
    say "FAIL" label "needle=" needle
    exit 1
  end
  return

::requires "ImapSession.cls"
::requires "TestSupport.cls"
