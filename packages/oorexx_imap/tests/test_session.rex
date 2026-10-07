crlf = "0d0a"x
chunks = .array~new
chunks~append("* OK [CAPABILITY IMAP4rev1 UIDPLUS MOVE CONDSTORE QRESYNC ESEARCH LITERAL+] ready" || crlf)
chunks~append("* CAPABILITY IMAP4rev1 UIDPLUS MOVE CONDSTORE QRESYNC ESEARCH LITERAL+" || crlf || "A000001 OK capability" || crlf)
chunks~append("* FLAGS (\Answered \Flagged \Deleted \Seen \Draft)" || crlf ||,
              "* 100 EXISTS" || crlf ||,
              "* 20 RECENT" || crlf ||,
              "* OK [UNSEEN 3] first unseen sequence" || crlf ||,
              "* OK [UIDVALIDITY 777] valid" || crlf ||,
              "* OK [UIDNEXT 1001] predicted" || crlf ||,
              "* OK [HIGHESTMODSEQ 9001] modseq" || crlf ||,
              "A000002 OK [READ-ONLY] EXAMINE completed" || crlf)
chunks~append('* ESEARCH (TAG "A000003") UID COUNT 179000 MIN 1 MAX 999999 ALL 1:999999' || crlf || "A000003 OK search" || crlf)
t = .ImapScriptedTransport~new(chunks)
s = .ImapSession~new(t)
g = s~acceptGreeting
call assert s~capabilities~has("QRESYNC"), "greeting capability capture"
r = s~capability
call assert r~ok, "CAPABILITY OK"
r = s~examine("INBOX")
call assert r~ok, "EXAMINE OK"
st = s~selectedState
call assert st~exists = 100, "exists parsed"
call assert st~firstUnseenSequence = 3, "UNSEEN response code is first unseen sequence, preserved as protocol field"
call assert st~uidValidity = "777", "uidvalidity parsed"
call assert st~highestModSeq = "9001", "modseq parsed"
call assert st~readOnly, "read-only parsed"
pair = s~uidSearch("UNSEEN", "COUNT MIN MAX ALL")
call assert pair[1]~ok, "ESEARCH command OK"
search = pair[2]
call assert search~count = 179000, "ESEARCH count parsed without UID materialization"
call assert search~all~rangeCount = 1, "ESEARCH compact ALL range"
call assert search~all~count = 999999, "compact range count"

writes = t~writes
call assert writes[1] = "A000001 CAPABILITY" || crlf, "first command tag"
call assert writes[2] = 'A000002 EXAMINE "INBOX"' || crlf, "quoted mailbox"
call assert writes[3] = "A000003 UID SEARCH RETURN (COUNT MIN MAX ALL) UNSEEN" || crlf, "ESEARCH RETURN used"

say "PASS test_session"
exit 0
assert: procedure
  use strict arg condition, message
  if \condition then do; say "FAIL:" message; exit 1; end
  return

::requires "ImapSession.cls"
::requires "TestSupport.cls"
