crlf = "0d0a"x
chunks = .array~of("* OK ready" || crlf)
t = .ImapScriptedTransport~new(chunks)
s = .ImapSession~new(t); s~acceptGreeting
signal on syntax name expected
ignored = s~uidFetchPeek("1:10", "UID BODY[]")
signal off syntax
say "FAIL: BODY[] was accepted by read-only typed fetch"
exit 1
expected:
  signal off syntax
  if condition("A")[1] <> "IMAP_PEEK_REQUIRED" then do; say "FAIL: wrong guard exception" condition("A")[1]; exit 1; end
say "PASS test_peek_guard"
exit 0

::requires "ImapSession.cls"
::requires "TestSupport.cls"
