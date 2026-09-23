/* Read-only live probe for a disposable IMAP account.
 *
 * Protocol and transport security are independent. Canonical security values:
 *   IMPLICIT_TLS       (usual IMAPS / port 993)
 *   STARTTLS_REQUIRED  (IMAP port 143, mandatory STARTTLS upgrade)
 *   PLAINTEXT          (diagnostic only; login() will still reject passwords)
 *
 * Password acquisition is intentionally outside argv. Prefer
 * IMAP_PASSWORD_FILE; IMAP_PROBE_PASSWORD remains a dev-only compatibility
 * fallback and is never printed or retained by ImapSession.
 */
parse arg host user bridge mailbox security portArg
if host = "" | user = "" | bridge = "" then do
  say "usage: rexx imap-readonly-probe.rex HOST USER OPENSSL_BRIDGE_DIR [MAILBOX [SECURITY [PORT]]]"
  say "SECURITY: IMPLICIT_TLS | STARTTLS_REQUIRED | PLAINTEXT"
  say "set IMAP_PASSWORD_FILE (preferred) or IMAP_PROBE_PASSWORD; no password argv is supported"
  exit 2
end
if mailbox = "" then mailbox = "INBOX"
if security = "" then security = "IMPLICIT_TLS"

password = ""
passwordFile = value("IMAP_PASSWORD_FILE",, "ENVIRONMENT")
if passwordFile <> "" then do
  password = linein(passwordFile)
  call stream passwordFile, "C", "CLOSE"
end
else password = value("IMAP_PROBE_PASSWORD",, "ENVIRONMENT")
if password = "" then do; say "no IMAP password available"; exit 2; end

cfg = .ImapSocketTransportConfig~new
cfg~host = host
cfg~security = security
if portArg <> "" then cfg~port = portArg + 0
cfg~bridgeDirectory = bridge
transport = .ImapSocketTransport~new(cfg)
session = .ImapSession~new(transport)

boot = session~bootstrapSecurity(cfg~security)
say "security:" transport~security "port:" cfg~port "encrypted:" transport~encrypted
say "greeting:" session~greeting~firstLine
say "capability status:" boot~status "count:" session~capabilities~items

login = session~login(user, password)
password = ""
if \login~ok then do; say "login failed:" login~status login~text; transport~close; exit 3; end
/* CAPABILITY is a snapshot. Refresh after authentication because the server may
 * expose a different extension set in authenticated state. */
session~capability
result = session~examine(mailbox)
if \result~ok then do; say "EXAMINE failed:" result~status result~text; session~logout; transport~close; exit 4; end
s = session~selectedState
say "mailbox:" s~mailbox
say "messages:" s~exists
say "uidvalidity:" s~uidValidity
say "uidnext:" s~uidNext
say "highestmodseq:" s~highestModSeq
say "read-only:" s~readOnly
status = session~status(mailbox)
if status <> .nil then say "status unseen-count:" status~unseenCount
session~logout
transport~close
exit 0

::requires "ImapApiTlsTransport.cls"
