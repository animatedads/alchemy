crlf = "0d0a"x
chunks = .array~new
chunks~append("* OK ready" || crlf)
chunks~append("* CAPABILITY IMAP4rev1 UIDPLUS LITERAL+" || crlf || "A000001 OK capability" || crlf)
chunks~append("A000002 OK [APPENDUID 77 123] appended" || crlf)
t = .ImapScriptedTransport~new(chunks)
s = .ImapSession~new(t)
s~acceptGreeting
s~capability
msg = "Subject: tiny" || crlf || crlf || "hello"
r = s~appendBytes("INBOX", msg, "\Seen", "01-Jan-2020 00:00:00 +0000")
call assert r~ok, "append with LITERAL+"
w = t~writes
expectedPrefix = 'A000002 APPEND "INBOX" (\Seen) "01-Jan-2020 00:00:00 +0000" {' || msg~length || '+}' || crlf
call assert w[2] = expectedPrefix, "literal+ prefix"
call assert w[3] = msg, "literal bytes separate"
call assert w[4] = crlf, "command terminator after literal"

/* Without LITERAL+ we must wait for a continuation before sending bytes. */
chunks2 = .array~of("* OK ready" || crlf, "+ go ahead" || crlf, "A000001 OK appended" || crlf)
t2 = .ImapScriptedTransport~new(chunks2)
s2 = .ImapSession~new(t2); s2~acceptGreeting
r2 = s2~appendBytes("INBOX", "abc")
call assert r2~ok, "synchronizing literal append"
call assert r2~continuations~items = 1, "continuation retained"

say "PASS test_append_literal"
exit 0
assert: procedure
  use strict arg condition, message
  if \condition then do; say "FAIL:" message; exit 1; end
  return

::requires "ImapSession.cls"
::requires "TestSupport.cls"
