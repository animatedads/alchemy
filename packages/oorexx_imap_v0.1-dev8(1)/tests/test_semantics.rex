/* Semantic mutation qualification: generic and Citadel profiles. */
call assertEq .ImapMailboxRole~canonical("\Sent"), "SENT", "special-use role canonicalization"
call assertEq .ImapMutationIntent~canonical("send"), "SUBMIT", "submission alias"

generic = .ImapServerBehaviorProfile~generic
call assertEq generic~name, "GENERIC", "generic profile"
d = generic~planAppend("ordinary", "store")
call assertTrue d~allowed, "generic ordinary APPEND is passive store"
call assertEq d~actualEffect, "PASSIVE_STORE", "generic ordinary effect"
d = generic~planAppend("sent", "migrate")
call assertTrue \d~allowed, "generic Sent migration is not assumed passive"
call assertTrue d~requiresExplicitPolicy, "generic Sent requires policy"
call assertEq d~actualEffect, "SERVER_DEFINED", "generic Sent semantics remain server-defined"

citadel = .ImapServerBehaviorProfile~citadel
call assertEq citadel~name, "CITADEL", "Citadel profile"
call assertTrue citadel~smtpAutoRecordsSent, "Citadel SMTP records Sent"
call assertTrue \citadel~shouldClientAppendSentAfterSmtp, "do not append duplicate Sent after Citadel SMTP"
d = citadel~planAppend("ordinary", "post")
call assertTrue d~allowed, "Citadel ordinary room can be intentionally posted"
call assertEq d~actualEffect, "POST", "Citadel ordinary APPEND effect"
d = citadel~planAppend("sent", "submit")
call assertTrue d~allowed, "Citadel Sent APPEND can intentionally submit"
call assertEq d~actualEffect, "SUBMIT", "Citadel Sent APPEND effect"
d = citadel~planAppend("sent", "restore")
call assertTrue \d~allowed, "Citadel restore into Sent blocked by default"
call assertEq d~reason, "SEMANTIC_MISMATCH", "Citadel restore mismatch reason"
d = citadel~planAppend("ordinary", "migrate")
call assertTrue \d~allowed, "Citadel room migration is not silently treated as passive store"

say "PASS test_semantics"
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

::requires "ImapSemantics.cls"
