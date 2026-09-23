/* Controlled live IMAP mutation probe.
 *
 * Creates a NEW ordinary mailbox, APPENDs one small known message, obtains the
 * destination UID (APPENDUID when available, otherwise Message-ID search), and
 * verifies the stored bytes through BODY.PEEK[].  It deliberately RETAINS the
 * created mailbox/message: provider delete/expunge semantics are a separate
 * qualification surface and must not be guessed by a generic round-trip test.
 *
 * Safety gates:
 *   IMAP_MUTATION_ENABLE=YES
 *   IMAP_PASSWORD_FILE preferred; password is never accepted in argv.
 */
parse arg host user bridge mailbox security portArg
if host = "" | user = "" | bridge = "" | mailbox = "" then do
  say "usage: rexx imap-append-roundtrip-probe.rex HOST USER OPENSSL_BRIDGE_DIR MAILBOX [SECURITY [PORT]]"
  say "requires IMAP_MUTATION_ENABLE=YES and IMAP_PASSWORD_FILE"
  exit 2
end
if value("IMAP_MUTATION_ENABLE",, "ENVIRONMENT") <> "YES" then do
  say "mutation disabled: set IMAP_MUTATION_ENABLE=YES explicitly"
  exit 2
end
if mailbox~upper = "INBOX" then do
  say "refusing mutation probe against INBOX; provide a new disposable mailbox name"
  exit 2
end
if security = "" then security = "IMPLICIT_TLS"

passwordFile = value("IMAP_PASSWORD_FILE",, "ENVIRONMENT")
if passwordFile = "" then do; say "IMAP_PASSWORD_FILE is required for mutation probe"; exit 2; end
password = linein(passwordFile)
call stream passwordFile, "C", "CLOSE"
if password = "" then do; say "password file was empty"; exit 2; end

cfg = .ImapSocketTransportConfig~new
cfg~host = host
cfg~security = security
if portArg <> "" then cfg~port = portArg + 0
cfg~bridgeDirectory = bridge
transport = .ImapSocketTransport~new(cfg)
session = .ImapSession~new(transport)

boot = session~bootstrapSecurity(cfg~security)
if \boot~ok then do; say "bootstrap failed:" boot~status; transport~close; exit 3; end
login = session~login(user, password)
password = ""
if \login~ok then do; say "login failed:" login~status; transport~close; exit 3; end
session~capability

/* CREATE is intentional: if the supplied name already exists, stop rather
 * than silently APPENDing into an existing or special-use mailbox. */
created = session~createMailbox(mailbox)
if \created~ok then do
  say "CREATE failed/refused; mailbox must be new:" created~status created~text
  session~logout; transport~close; exit 4
end

crlf = "0d0a"x
stamp = date("S") || "-" || time("S") || "-" || random(100000, 999999)
messageId = "<oorexx-imap-" || stamp || "@example.invalid>"
msg = "From: oorexx-imap@example.invalid" || crlf || -
      "To: oorexx-imap@example.invalid" || crlf || -
      "Subject: ooRexx IMAP APPEND qualification " || stamp || crlf || -
      "Message-ID: " || messageId || crlf || -
      "Date: " || date("N") || " " || time("N") || " +0000" || crlf || -
      "Content-Type: text/plain; charset=utf-8" || crlf || crlf || -
      "known round-trip payload " || stamp || crlf

profile = .ImapServerBehaviorProfile~generic
appended = session~appendBytesWithIntentResult(mailbox, msg, profile, "ORDINARY", "STORE")
if \appended~ok then do
  say "APPEND failed:" appended~commandResult~status appended~commandResult~text
  session~logout; transport~close; exit 5
end

examined = session~examine(mailbox)
if \examined~ok then do; say "EXAMINE failed:" examined~status; session~logout; transport~close; exit 6; end

uid = ""
if appended~hasAppendUid then do
  if appended~uidSet~count = 1 then uid = appended~uidSet~toArray(1)[1]
end
if uid = "" then do
  pair = session~uidSearch("HEADER Message-ID " || .ImapCodec~quoteString(messageId))
  sr = pair[2]
  if sr~count = 1 then uid = sr~all~toArray(1)[1]
end
if uid = "" then do
  say "could not identify exactly one appended UID; retained mailbox:" mailbox
  session~closeMailbox; session~logout; transport~close; exit 7
end

fetched = session~uidFetchBodyPeek(uid)
if \fetched~ok then do
  say "BODY.PEEK verification fetch failed; retained mailbox:" mailbox "uid:" uid
  session~closeMailbox; session~logout; transport~close; exit 8
end
returned = .nil
do record over fetched~untagged
  if record~literalSegments~items > 0 then do
    returned = record~literalSegments[1]~bytes
    leave
  end
end
if returned == .nil then do
  say "verification response contained no retained literal; retained mailbox:" mailbox "uid:" uid
  session~closeMailbox; session~logout; transport~close; exit 9
end
if returned \== msg then do
  say "round-trip bytes differ; retained mailbox:" mailbox "uid:" uid
  say "expected-bytes:" msg~length "returned-bytes:" returned~length
  session~closeMailbox; session~logout; transport~close; exit 10
end

session~closeMailbox
session~logout
transport~close
say "PASS live APPEND/BODY.PEEK round trip"
say "mailbox:" mailbox
say "uid:" uid
say "uidvalidity:" appended~uidValidity
say "bytes:" msg~length
say "retained: yes (cleanup semantics intentionally not assumed)"
exit 0

::requires "ImapApiTlsTransport.cls"
