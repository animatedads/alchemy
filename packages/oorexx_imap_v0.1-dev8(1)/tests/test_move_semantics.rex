crlf="0d0a"x
/* Native MOVE path. */
chunks=.array~of( -
  "* OK [CAPABILITY IMAP4rev1 MOVE UIDPLUS] ready"||crlf, -
  "* 1 EXISTS"||crlf||"* OK [UIDVALIDITY 10] valid"||crlf||"A000001 OK [READ-WRITE] selected"||crlf, -
  "A000002 OK [COPYUID 20 7 70] moved"||crlf )
t=.ImapScriptedTransport~new(chunks); s=.ImapSession~new(t); s~acceptGreeting; call assert s~select("SRC")~ok,"select native"
r=.ImapTransferOps~moveSameSession(s,"7","DST",.false,.true,"ORDINARY")
call assert r~ok,"native move complete"
call assert r~strategy="UID_MOVE","native strategy"
call assert r~destinationResult~destinationUidFor(7)=70,"native destination mapping"
call assert t~writes[2]='A000002 UID MOVE 7 "DST"'||crlf,"native move wire"

/* MOVE unavailable: UIDPLUS gives exact COPY + delete + UID EXPUNGE. */
chunks2=.array~of( -
  "* OK [CAPABILITY IMAP4rev1 UIDPLUS] ready"||crlf, -
  "* 1 EXISTS"||crlf||"* OK [UIDVALIDITY 11] valid"||crlf||"A000001 OK [READ-WRITE] selected"||crlf, -
  "A000002 OK [COPYUID 21 8 80] copied"||crlf, -
  "A000003 OK flags"||crlf, -
  "* 1 EXPUNGE"||crlf||"A000004 OK expunged"||crlf )
t2=.ImapScriptedTransport~new(chunks2); s2=.ImapSession~new(t2); s2~acceptGreeting; call assert s2~select("SRC")~ok,"select fallback"
r2=.ImapTransferOps~moveSameSession(s2,"8","DST",.false,.true,"ORDINARY")
call assert r2~ok,"fallback exact move complete"
call assert r2~strategy="UID_COPY_UID_EXPUNGE","fallback strategy"
call assert r2~sourceRemoval~sourceRemovalComplete,"fallback removal complete"
w=t2~writes
call assert w[2]='A000002 UID COPY 8 "DST"'||crlf,"copy wire"
call assert w[3]='A000003 UID STORE 8 +FLAGS.SILENT (\Deleted)'||crlf,"mark deleted wire"
call assert w[4]='A000004 UID EXPUNGE 8'||crlf,"uid expunge wire"

/* Without MOVE or UIDPLUS, fail before duplicating unless caller explicitly accepts pending expunge. */
chunks3=.array~of("* OK [CAPABILITY IMAP4rev1] ready"||crlf, "* 1 EXISTS"||crlf||"A000001 OK [READ-WRITE] selected"||crlf)
t3=.ImapScriptedTransport~new(chunks3); s3=.ImapSession~new(t3); s3~acceptGreeting; call assert s3~select("SRC")~ok,"select blocked"
signal on syntax name expectedBlocked
ignore=.ImapTransferOps~moveSameSession(s3,"9","DST",.false,.true,"ORDINARY")
say "FAIL unsafe move should block"; exit 1
expectedBlocked:
signal off syntax
call assert t3~writes~items=1,"blocked move writes nothing after SELECT"

/* Explicit pending-expunge mode copies and marks only; never sends plain EXPUNGE. */
chunks4=.array~of("* OK [CAPABILITY IMAP4rev1] ready"||crlf, "* 1 EXISTS"||crlf||"A000001 OK [READ-WRITE] selected"||crlf, "A000002 OK copied"||crlf, "A000003 OK marked"||crlf)
t4=.ImapScriptedTransport~new(chunks4); s4=.ImapSession~new(t4); s4~acceptGreeting; call assert s4~select("SRC")~ok,"select pending"
r4=.ImapTransferOps~moveSameSession(s4,"9","DST",.true,.true,"ORDINARY")
call assert \r4~complete & r4~pendingExpunge,"pending expunge reported"
call assert r4~strategy="UID_COPY_MARK_DELETED","pending strategy"
call assert t4~writes~items=3,"no unsafe EXPUNGE command"

/* Destination role is mandatory at the high-level boundary. */
signal on syntax name roleBlocked
ignore=.ImapTransferOps~moveSameSession(s4,"9","DST")
say "FAIL role-less move should block"; exit 1
roleBlocked:
signal off syntax
call assert t4~writes~items=3,"role-less move writes nothing"

/* High-level move refuses special-use destinations until an explicit server policy exists. */
chunks5=.array~of("* OK [CAPABILITY IMAP4rev1 MOVE UIDPLUS] ready"||crlf, "* 1 EXISTS"||crlf||"A000001 OK [READ-WRITE] selected"||crlf)
t5=.ImapScriptedTransport~new(chunks5); s5=.ImapSession~new(t5); s5~acceptGreeting; call assert s5~select("SRC")~ok,"select special block"
signal on syntax name specialBlocked
ignore=.ImapTransferOps~moveSameSession(s5,"1","Sent",.false,.true,"SENT")
say "FAIL special-use move should block"; exit 1
specialBlocked:
signal off syntax
call assert t5~writes~items=1,"special-use block writes nothing"

/* Destination equal to source is rejected before wire mutation. */
signal on syntax name sameBlocked
ignore=.ImapTransferOps~moveSameSession(s5,"1","SRC",.false,.true,"ORDINARY")
say "FAIL same-mailbox move should block"; exit 1
sameBlocked:
signal off syntax
call assert t5~writes~items=1,"same-mailbox block writes nothing"

/* COPY failure must never start source deletion. */
chunks6=.array~of("* OK [CAPABILITY IMAP4rev1 UIDPLUS] ready"||crlf, "* 1 EXISTS"||crlf||"A000001 OK [READ-WRITE] selected"||crlf, "A000002 NO destination refused"||crlf)
t6=.ImapScriptedTransport~new(chunks6); s6=.ImapSession~new(t6); s6~acceptGreeting; call assert s6~select("SRC")~ok,"select copy fail"
r6=.ImapTransferOps~moveSameSession(s6,"2","DST",.false,.true,"ORDINARY")
call assert \r6~complete & \r6~destinationAccepted,"copy failure surfaced"
call assert t6~writes~items=2,"copy failure sends no delete"

/* Mark-deleted failure must never proceed to UID EXPUNGE. */
chunks7=.array~of("* OK [CAPABILITY IMAP4rev1 UIDPLUS] ready"||crlf, "* 1 EXISTS"||crlf||"A000001 OK [READ-WRITE] selected"||crlf, "A000002 OK [COPYUID 33 3 30] copied"||crlf, "A000003 NO cannot mark"||crlf)
t7=.ImapScriptedTransport~new(chunks7); s7=.ImapSession~new(t7); s7~acceptGreeting; call assert s7~select("SRC")~ok,"select store fail"
r7=.ImapTransferOps~moveSameSession(s7,"3","DST",.false,.true,"ORDINARY")
call assert \r7~complete & r7~destinationAccepted,"store failure leaves destination copy"
call assert r7~reason="MARK_DELETED_FAILED","store failure reason"
call assert t7~writes~items=3,"store failure sends no expunge"

say "PASS test_move_semantics"
exit 0
assert: procedure
  use strict arg condition,message
  if \condition then do; say "FAIL:" message; exit 1; end
  return
::requires "ImapTransfer.cls"
::requires "TestSupport.cls"
