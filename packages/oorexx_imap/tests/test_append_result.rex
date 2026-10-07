crlf = "0d0a"x
chunks = .array~new
chunks~append("* OK ready" || crlf)
chunks~append("* CAPABILITY IMAP4rev1 UIDPLUS LITERAL+" || crlf || "A000001 OK capability" || crlf)
chunks~append("A000002 OK [APPENDUID 777 42] appended" || crlf)
t = .ImapScriptedTransport~new(chunks)
s = .ImapSession~new(t)
s~acceptGreeting
s~capability
msg = "Subject: roundtrip" || crlf || crlf || "hello"
a = s~appendBytesResult("OO-TEST", msg)
call assert a~ok, "append result ok"
call assert a~hasAppendUid, "APPENDUID detected"
call assert a~uidValidity = "777", "APPENDUID UIDVALIDITY"
call assert a~uidSet~wire = "42", "APPENDUID UID set"

/* APPENDUID can legally return a UID set, not merely one number. */
r = .ImapCommandResult~new("A9", "OK", "[APPENDUID 888 11:13,20] copied")
a2 = s~parseAppendResult(r)
call assert a2~hasAppendUid, "ranged APPENDUID detected"
call assert a2~uidValidity = "888", "ranged UIDVALIDITY"
call assert a2~uidSet~wire = "11:13,20", "ranged UID set remains compact"
call assert a2~uidSet~count = 4, "ranged UID set count"

r2 = .ImapCommandResult~new("A10", "OK", "append complete")
a3 = s~parseAppendResult(r2)
call assert \a3~hasAppendUid, "append without UIDPLUS remains valid"
call assert a3~uidSet == .nil, "no synthetic UID invented"

say "PASS test_append_result"
exit 0
assert: procedure
  use strict arg condition, message
  if \condition then do; say "FAIL:" message; exit 1; end
  return

::requires "ImapSession.cls"
::requires "TestSupport.cls"
