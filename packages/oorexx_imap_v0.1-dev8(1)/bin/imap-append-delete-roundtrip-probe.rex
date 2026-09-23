/* Controlled live APPEND -> verify -> exact source-removal qualification.
 *
 * This deliberately exercises the non-MOVE migration recipe.  It creates two
 * NEW ordinary mailboxes, APPENDs a known source message, obtains metadata and
 * bytes with PEEK, APPENDs a destination copy, verifies exact destination bytes,
 * then and only then commits source removal using UID STORE \\Deleted followed
 * by UID EXPUNGE.  UIDPLUS is therefore required; plain EXPUNGE is forbidden.
 */
parse arg host user bridge sourceMailbox destinationMailbox security portArg
if host="" | user="" | bridge="" | sourceMailbox="" | destinationMailbox="" then do
  say "usage: rexx imap-append-delete-roundtrip-probe.rex HOST USER OPENSSL_BRIDGE SOURCE_MAILBOX DEST_MAILBOX [SECURITY [PORT]]"
  say "requires IMAP_MUTATION_ENABLE=YES, IMAP_TRANSFER_DELETE_ENABLE=YES and IMAP_PASSWORD_FILE"
  exit 2
end
if value("IMAP_MUTATION_ENABLE",,"ENVIRONMENT")<>"YES" then do; say "mutation disabled"; exit 2; end
if value("IMAP_TRANSFER_DELETE_ENABLE",,"ENVIRONMENT")<>"YES" then do; say "transfer-delete disabled"; exit 2; end
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
if \boot~ok then do; say "bootstrap failed"; transport~close; exit 3; end
login=session~login(user,password); password=""
if \login~ok then do; say "login failed"; transport~close; exit 3; end
session~capability
if \session~capabilities~has("UIDPLUS") then do; say "UIDPLUS required for exact source removal"; session~logout; transport~close; exit 3; end

c1=session~createMailbox(sourceMailbox)
if \c1~ok then do; say "source CREATE failed; use a new mailbox"; session~logout; transport~close; exit 4; end
c2=session~createMailbox(destinationMailbox)
if \c2~ok then do; say "destination CREATE failed; source retained:" sourceMailbox; session~logout; transport~close; exit 4; end

crlf="0d0a"x
stamp=date("S")||"-"||time("S")||"-"||random(100000,999999)
messageId="<oorexx-imap-append-delete-"||stamp||"@example.invalid>"
msg="From: oorexx-imap@example.invalid"||crlf|| -
    "To: oorexx-imap@example.invalid"||crlf|| -
    "Subject: ooRexx IMAP APPEND-delete qualification "||stamp||crlf|| -
    "Message-ID: "||messageId||crlf|| -
    "Date: "||date("N")||" "||time("N")||" +0000"||crlf|| -
    "Content-Type: text/plain; charset=utf-8"||crlf||crlf|| -
    "known APPEND-delete payload "||stamp||crlf
profile=.ImapServerBehaviorProfile~generic
app=session~appendBytesWithIntentResult(sourceMailbox,msg,profile,"ORDINARY","STORE")
if \app~ok then do; say "source APPEND failed"; session~logout; transport~close; exit 5; end

ex=session~examine(sourceMailbox)
if \ex~ok then do; say "source EXAMINE failed"; session~logout; transport~close; exit 6; end
sourceUid=""
if app~hasAppendUid & app~uidSet~count=1 then sourceUid=app~uidSet~uidAtOrdinal(1)
if sourceUid="" then do
  pair=session~uidSearch("HEADER Message-ID "||.ImapCodec~quoteString(messageId))
  if pair[2]~count=1 then sourceUid=pair[2]~all~uidAtOrdinal(1)
end
if sourceUid="" then do; say "source UID unresolved"; session~closeMailbox; session~logout; transport~close; exit 7; end
metaPair=.ImapTransferOps~fetchTransferMetadata(session,sourceUid); meta=metaPair[2]
if meta==.nil then do; say "source transfer metadata unavailable"; session~closeMailbox; session~logout; transport~close; exit 8; end
fetch=session~uidFetchBodyPeek(sourceUid)
if \fetch~ok then do; say "source BODY.PEEK failed"; session~closeMailbox; session~logout; transport~close; exit 9; end
raw=.nil
do rec over fetch~untagged
  if rec~literalCount>0 then do; raw=rec~literalSegments[1]~bytes; leave; end
end
if raw==.nil | raw\==msg then do; say "source bytes differ before transfer"; session~closeMailbox; session~logout; transport~close; exit 10; end
session~closeMailbox

safeFlags=.ImapTransferOps~appendableFlags(meta~flags)
destApp=session~appendBytesWithIntentResult(destinationMailbox,raw,profile,"ORDINARY","MIGRATE",safeFlags,meta~internalDate)
if \destApp~ok then do; say "destination APPEND failed; source retained"; session~logout; transport~close; exit 11; end
exd=session~examine(destinationMailbox)
if \exd~ok then do; say "destination EXAMINE failed; source retained"; session~logout; transport~close; exit 12; end
destUid=""
if destApp~hasAppendUid & destApp~uidSet~count=1 then destUid=destApp~uidSet~uidAtOrdinal(1)
if destUid="" then do
  dp=session~uidSearch("HEADER Message-ID "||.ImapCodec~quoteString(messageId))
  if dp[2]~count=1 then destUid=dp[2]~all~uidAtOrdinal(1)
end
if destUid="" then do; say "destination UID unresolved; source retained"; session~closeMailbox; session~logout; transport~close; exit 13; end
df=session~uidFetchBodyPeek(destUid); draw=.nil
do rec over df~untagged
  if rec~literalCount>0 then do; draw=rec~literalSegments[1]~bytes; leave; end
end
if \df~ok | draw==.nil | draw\==raw then do; say "destination verification failed; source retained"; session~closeMailbox; session~logout; transport~close; exit 14; end
session~closeMailbox

/* COMMIT source removal only after successful byte-for-byte destination verification. */
sel=session~select(sourceMailbox)
if \sel~ok then do; say "source SELECT for removal failed; destination retained"; session~logout; transport~close; exit 15; end
removed=.ImapTransferOps~commitSourceRemoval(session,sourceUid)
if \removed~sourceRemovalComplete then do; say "source removal incomplete:" removed~reason; session~closeMailbox; session~logout; transport~close; exit 16; end
session~closeMailbox

/* Prove source is absent and destination survived source deletion. */
exs=session~examine(sourceMailbox); sp=session~uidSearch("HEADER Message-ID "||.ImapCodec~quoteString(messageId))
if \exs~ok | sp[2]~count<>0 then do; say "source still contains transfer message"; session~closeMailbox; session~logout; transport~close; exit 17; end
session~closeMailbox
exd2=session~examine(destinationMailbox); dp2=session~uidSearch("HEADER Message-ID "||.ImapCodec~quoteString(messageId))
if \exd2~ok | dp2[2]~count<>1 then do; say "destination did not survive source removal"; session~closeMailbox; session~logout; transport~close; exit 18; end
verifyUid=dp2[2]~all~uidAtOrdinal(1); vf=session~uidFetchBodyPeek(verifyUid); vraw=.nil
do rec over vf~untagged
  if rec~literalCount>0 then do; vraw=rec~literalSegments[1]~bytes; leave; end
end
if \vf~ok | vraw==.nil | vraw\==raw then do; say "destination bytes changed after source removal"; session~closeMailbox; session~logout; transport~close; exit 19; end
session~closeMailbox; session~logout; transport~close
say "PASS live APPEND/verify/delete transfer"
say "source-mailbox:" sourceMailbox
say "destination-mailbox:" destinationMailbox
say "source-uid:" sourceUid
say "destination-uid:" verifyUid
say "bytes:" raw~length
say "retained: destination message + both mailboxes"
exit 0

::requires "ImapApiTlsTransport.cls"
::requires "ImapTransfer.cls"
