path = "/tmp/wlu_route_journal_rotation_test.log"
ignore = RxFuncAdd("SysFileDelete", "rxunixsys", "SysFileDelete")
ignore = SysFileDelete(path)
keys = .WLUFastMacKeyRing~new
keys~addKey("route-k1", "000102030405060708090a0b0c0d0e0f")
journal = .WLUJobRouteFileJournal~new(path, keys)

draft1 = .WLUJobRouteEvidence~new("job-rotate", 1, 1000000, .WLUJobRouteEventType~STAGE_RESERVED, "GEMMA", "", "r1", 0, 0, .false, 1000000, 2000000, 1, "WITHIN_BUDGET", "", "", "", "ai-common", "2026-08")
event1 = draft1~withProof(keys~sign(draft1~canonicalText))
a1 = journal~appendEvent(event1)
call assertTrue a1~ok, "first-key event archives"
call assertEq "route-k1", event1~proof~keyId, "first event key id"

keys~addKey("route-k2", "101112131415161718191a1b1c1d1e1f")
keys~activate("route-k2")
draft2 = .WLUJobRouteEvidence~new("job-rotate", 2, 2000000, .WLUJobRouteEventType~STAGE_SETTLED, "GEMMA", "", "r1", 900000, 100000, .true, 1000000, 2000000, 1, "WITHIN_BUDGET", "", "SUCCESS", "conversation:rotate", "ai-common", "2026-08")
event2 = draft2~withProof(keys~sign(draft2~canonicalText))
a2 = journal~appendEvent(event2)
call assertTrue a2~ok, "rotated-key event archives"
call assertEq "route-k2", event2~proof~keyId, "second event key id"

verified = journal~readVerified
call assertTrue verified~ok, "mixed-key chain verifies"
call assertEq 2, verified~value[1]~items, "mixed-key event count"
reopened = .WLUJobRouteFileJournal~new(path, keys)
call assertEq 2, reopened~sequence, "mixed-key journal recovers"
summary = reopened~summary("job-rotate")
call assertTrue summary~ok, "mixed-key summary derives"
call assertEq 1000000, summary~value~actualMicroWlu, "mixed-key actual WLU"
call assertEq 100000, summary~value~knownHandoffMicroWlu, "mixed-key handoff WLU"

say "PASS test_route_journal_rotation"
call SysFileDelete path
exit 0

assertEq: procedure
  use arg expected, actual, label
  if expected \== actual then do
    say "FAIL" label "expected="expected "actual="actual
    exit 1
  end
  return
assertTrue: procedure
  use arg condition, label
  if \condition then do
    say "FAIL" label
    exit 1
  end
  return

::requires "WLURouteJournal.cls"
