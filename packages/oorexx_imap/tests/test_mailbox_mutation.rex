crlf = "0d0a"x
chunks = .array~of( -
  "* OK ready" || crlf, -
  "A000001 OK created" || crlf, -
  "A000002 OK renamed" || crlf, -
  "A000003 OK subscribed" || crlf, -
  "A000004 OK unsubscribed" || crlf, -
  "* 0 EXISTS" || crlf || "A000005 OK [READ-ONLY] examined" || crlf, -
  "A000006 OK closed" || crlf, -
  "A000007 OK deleted" || crlf )
t = .ImapScriptedTransport~new(chunks)
s = .ImapSession~new(t)
s~acceptGreeting
call assert s~createMailbox("OO-A")~ok, "CREATE"
call assert s~renameMailbox("OO-A", "OO-B")~ok, "RENAME"
call assert s~subscribeMailbox("OO-B")~ok, "SUBSCRIBE"
call assert s~unsubscribeMailbox("OO-B")~ok, "UNSUBSCRIBE"
call assert s~examine("OO-B")~ok, "EXAMINE"
call assert s~selectedState \== .nil, "selected state set"
call assert s~closeMailbox~ok, "CLOSE"
call assert s~selectedState == .nil, "selected state cleared"
call assert s~deleteMailbox("OO-B")~ok, "DELETE"

w = t~writes
call assert w[1] = 'A000001 CREATE "OO-A"' || crlf, "CREATE wire"
call assert w[2] = 'A000002 RENAME "OO-A" "OO-B"' || crlf, "RENAME wire"
call assert w[3] = 'A000003 SUBSCRIBE "OO-B"' || crlf, "SUBSCRIBE wire"
call assert w[4] = 'A000004 UNSUBSCRIBE "OO-B"' || crlf, "UNSUBSCRIBE wire"
call assert w[5] = 'A000005 EXAMINE "OO-B"' || crlf, "EXAMINE wire"
call assert w[6] = 'A000006 CLOSE' || crlf, "CLOSE wire"
call assert w[7] = 'A000007 DELETE "OO-B"' || crlf, "DELETE wire"

say "PASS test_mailbox_mutation"
exit 0
assert: procedure
  use strict arg condition, message
  if \condition then do; say "FAIL:" message; exit 1; end
  return

::requires "ImapSession.cls"
::requires "TestSupport.cls"
