/* Controlled live same-server IMAP MOVE qualification.
 *
 * Creates two NEW ordinary mailboxes and one known message.  It prefers UID MOVE
 * when MOVE is advertised; otherwise the high-level transfer layer may use
 * UID COPY + STORE \\Deleted + UID EXPUNGE only when UIDPLUS makes exact expunge
 * possible.  It never falls back to plain EXPUNGE.
 *
 * Both mailboxes are deliberately retained for inspection.
 */
parse arg host user bridge sourceMailbox destinationMailbox security portArg
if host="" | user="" | bridge="" | sourceMailbox="" | destinationMailbox="" then do
  say "usage: rexx imap-move-roundtrip-probe.rex HOST USER OPENSSL_BRIDGE SOURCE_MAILBOX DEST_MAILBOX [SECURITY [PORT]]"
  say "requires IMAP_MUTATION_ENABLE=YES and IMAP_PASSWORD_FILE"
  exit 2
end
if value("IMAP_MUTATION_ENABLE",,"ENVIRONMENT")<>"YES" then do; say "mutation disabled: set IMAP_MUTATION_ENABLE=YES"; exit 2; end
if sourceMailbox~upper="INBOX" | destinationMailbox~upper="INBOX" then do; say "refusing qualification against INBOX"; exit 2; end
if sourceMailbox==destinationMailbox then do; say "source and destination mailboxes must differ"; exit 2; end
if security="" then security="IMPLICIT_TLS"
passwordFile=value("IMAP_PASSWORD_FILE",,"ENVIRONMENT")
if passwordFile="" then do; say "IMAP_PASSWORD_FILE is required"; exit 2; end
password=linein(passwordFile); call stream passwordFile,"C","CLOSE"
if password="" then do; say "password file was empty"; exit 2; end

cfg=.ImapSocketTransportConfig~new; cfg~host=host; cfg~security=security
if portArg<>"" then cfg~port=portArg+0
cfg~bridgeDirectory=bridge
transport=.ImapSocketTransport~new(cfg); session=.ImapSession~new(transport)
boot=session~bootstrapSecurity(cfg~security)
if \boot~ok then do; say "bootstrap failed:" boot~status; transport~close; exit 3; end
login=session~login(user,password); password=""
if \login~ok then do; say "login failed:" login~status; transport~close; exit 3; end
session~capability

created=session~createMailbox(sourceMailbox)
if \created~ok then do; say "source CREATE failed; use a new mailbox:" created~status created~text; session~logout; transport~close; exit 4; end
created2=session~createMailbox(destinationMailbox)
if \created2~ok then do; say "destination CREATE failed; source retained:" sourceMailbox; session~logout; transport~close; exit 4; end

crlf="0d0a"x
stamp=date("S")||"-"||time("S")||"-"||random(100000,999999)
messageId="<oorexx-imap-move-"||stamp||"@example.invalid>"
msg="From: oorexx-imap@example.invalid"||crlf|| -
    "To: oorexx-imap@example.invalid"||crlf|| -
    "Subject: ooRexx IMAP MOVE qualification "||stamp||crlf|| -
    "Message-ID: "||messageId||crlf|| -
    "Date: "||date("N")||" "||time("N")||" +0000"||crlf|| -
    "Content-Type: text/plain; charset=utf-8"||crlf||crlf|| -
    "known MOVE payload "||stamp||crlf
profile=.ImapServerBehaviorProfile~generic
app=session~appendBytesWithIntentResult(sourceMailbox,msg,profile,"ORDINARY","STORE")
if \app~ok then do; say "source APPEND failed:" app~commandResult~status app~commandResult~text; session~logout; transport~close; exit 5; end

sel=session~select(sourceMailbox)
if \sel~ok then do; say "source SELECT failed:" sel~status; session~logout; transport~close; exit 6; end
sourceUid=""
if app~hasAppendUid & app~uidSet~count=1 then sourceUid=app~uidSet~uidAtOrdinal(1)
if sourceUid="" then do
  pair=session~uidSearch("HEADER Message-ID "||.ImapCodec~quoteString(messageId))
  if pair[2]~count=1 then sourceUid=pair[2]~all~uidAtOrdinal(1)
end
if sourceUid="" then do; say "could not identify source UID; retained mailboxes"; session~closeMailbox; session~logout; transport~close; exit 7; end

move=.ImapTransferOps~moveSameSession(session,sourceUid,destinationMailbox,.false,.true,"ORDINARY")
if \move~complete then do
  say "move did not complete; strategy:" move~strategy "reason:" move~reason
  say "retained mailboxes:" sourceMailbox destinationMailbox
  session~closeMailbox; session~logout; transport~close; exit 8
end
session~closeMailbox

exam=session~examine(destinationMailbox)
if \exam~ok then do; say "destination EXAMINE failed"; session~logout; transport~close; exit 9; end
destinationUid=""
map=move~destinationResult
if map\==.nil then if map~hasCopyUid & map~mappingCountMatches then destinationUid=map~destinationUidFor(sourceUid)
if destinationUid=0 then destinationUid=""
if destinationUid="" then do
  pair=session~uidSearch("HEADER Message-ID "||.ImapCodec~quoteString(messageId))
  if pair[2]~count=1 then destinationUid=pair[2]~all~uidAtOrdinal(1)
end
if destinationUid="" then do; say "destination UID not uniquely identifiable"; session~closeMailbox; session~logout; transport~close; exit 10; end
f=session~uidFetchBodyPeek(destinationUid)
if \f~ok then do; say "destination BODY.PEEK failed"; session~closeMailbox; session~logout; transport~close; exit 11; end
returned=.nil
do rec over f~untagged
  if rec~literalCount>0 then do; returned=rec~literalSegments[1]~bytes; leave; end
end
if returned==.nil | returned\==msg then do; say "destination bytes differ"; session~closeMailbox; session~logout; transport~close; exit 12; end
session~closeMailbox

/* Fresh source mailbox must no longer contain the qualification Message-ID. */
exam2=session~examine(sourceMailbox)
if \exam2~ok then do; say "source re-EXAMINE failed"; session~logout; transport~close; exit 13; end
pair2=session~uidSearch("HEADER Message-ID "||.ImapCodec~quoteString(messageId))
if pair2[2]~count<>0 then do; say "source still contains moved message"; session~closeMailbox; session~logout; transport~close; exit 14; end
session~closeMailbox; session~logout; transport~close
say "PASS live IMAP move round trip"
say "strategy:" move~strategy
say "source-mailbox:" sourceMailbox
say "destination-mailbox:" destinationMailbox
say "source-uid:" sourceUid
say "destination-uid:" destinationUid
say "bytes:" msg~length
say "retained: yes"
exit 0

::requires "ImapApiTlsTransport.cls"
::requires "ImapTransfer.cls"
