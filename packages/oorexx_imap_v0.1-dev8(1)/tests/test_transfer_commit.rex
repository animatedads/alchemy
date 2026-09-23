crlf="0d0a"x
/* Cross-server workflow commits source deletion only after caller asks for it. */
chunks=.array~of( -
  "* OK [CAPABILITY IMAP4rev1 UIDPLUS] ready"||crlf, -
  "* 1 EXISTS"||crlf||"* OK [UIDVALIDITY 13] valid"||crlf||"A000001 OK [READ-WRITE] selected"||crlf, -
  '* 1 FETCH (UID 12 FLAGS (\Seen custom) INTERNALDATE "16-Sep-2026 14:30:00 +0100" RFC822.SIZE 323)'||crlf||"A000002 OK metadata"||crlf, -
  "A000003 OK marked"||crlf, -
  "* 1 EXPUNGE"||crlf||"A000004 OK expunged"||crlf )
t=.ImapScriptedTransport~new(chunks); s=.ImapSession~new(t); s~acceptGreeting; call assert s~select("SRC")~ok,"select"
pair=.ImapTransferOps~fetchTransferMetadata(s,"12")
call assert pair[1]~ok,"metadata command"
m=pair[2]
call assert m\==.nil & m~uid="12","metadata uid"
call assert m~size=323,"metadata size"
call assert m~flags="\Seen custom","metadata flags"
call assert m~internalDate="16-Sep-2026 14:30:00 +0100","metadata date"
call assert .ImapTransferOps~appendableFlags("\Seen \Recent \Deleted custom")="\Seen custom","unsafe/nonportable transfer flags removed"
call assert .ImapTransferOps~appendableFlags("\Seen \Deleted custom",.true)="\Seen \Deleted custom","explicit deleted preservation"

/* No source mutation has happened until explicit commit. */
call assert t~writes~items=2,"metadata is observational"
r=.ImapTransferOps~commitSourceRemoval(s,"12")
call assert r~ok,"source removal commit"
call assert t~writes[3]='A000003 UID STORE 12 +FLAGS.SILENT (\Deleted)'||crlf,"commit mark"
call assert t~writes[4]='A000004 UID EXPUNGE 12'||crlf,"commit exact expunge"

/* Read-only selections cannot be removal authorities. */
chunks2=.array~of("* OK [CAPABILITY IMAP4rev1 UIDPLUS] ready"||crlf, "* 1 EXISTS"||crlf||"A000001 OK [READ-ONLY] examined"||crlf)
t2=.ImapScriptedTransport~new(chunks2); s2=.ImapSession~new(t2); s2~acceptGreeting; call assert s2~examine("SRC")~ok,"examine"
signal on syntax name readonlyBlocked
ignore=.ImapTransferOps~commitSourceRemoval(s2,"1")
say "FAIL read-only commit should block"; exit 1
readonlyBlocked:
signal off syntax
call assert t2~writes~items=1,"read-only commit wrote nothing"

say "PASS test_transfer_commit"
exit 0
assert: procedure
  use strict arg condition,message
  if \condition then do; say "FAIL:" message; exit 1; end
  return
::requires "ImapTransfer.cls"
::requires "TestSupport.cls"
