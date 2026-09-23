r=.ImapIndexRecord~new("acct","INBOX",13,7,123,"Your Facebook login","Google Security <no-reply@accounts.google.com>","2026-09-16","\\Seen","<m7@example>")
call assert r~key="acct|INBOX|13|7", "durable message key"
call assert r~fromKey="no-reply@accounts.google.com", "normalized From address"
t=.ImapIndexText~tokens("Facebook FACEBOOK no-reply@accounts.google.com; reset-password")
call assert t~items=3, "tokens unique and punctuation-aware"
call assert has(t,"facebook"), "facebook token"
call assert has(t,"no-reply@accounts.google.com"), "email address remains one token"
call assert has(t,"reset-password"), "hyphenated token remains one token"
say "PASS test_index_core"
exit 0
has: procedure
  use strict arg a,w
  do x over a; if x=w then return .true; end
  return .false
assert: procedure
  use strict arg condition,message
  if \condition then do; say "FAIL:" message; exit 1; end
  return
::requires "ImapIndexCore.cls"
