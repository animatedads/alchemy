# Security

## Transport policy

Callers must choose `IMPLICIT_TLS`, `STARTTLS_REQUIRED`, or `PLAINTEXT` explicitly. Ambiguous labels (`IMAP`, `TLS`, `SSL`, `SSL/TLS`, `SECURE`) fail closed.

`STARTTLS_REQUIRED` never silently degrades to plaintext. If STARTTLS is not advertised or the TLS handshake/certificate/hostname verification fails, the session fails.

`login()` refuses to transmit password credentials over a transport that reports itself unencrypted, even when the endpoint security is explicitly `PLAINTEXT`.

## Credentials

Credentials are not accepted on the read-only probe command line and are never retained by `ImapSession`.

The probe prefers `IMAP_PASSWORD_FILE`. For the disposable Gmail account this may point to `$HOME/googlepassword`; permissions should be restricted by the user. Production credential acquisition should bind to Secret Broker rather than environment or ad-hoc files.

Protocol tracing must redact authentication payloads before authenticated live qualification is enabled.

## Mailbox safety

Background body access uses `BODY.PEEK[...]`. Typed read-only helpers reject known seen-mutating FETCH forms. Initial public-server qualification uses `EXAMINE` rather than writable `SELECT`.


## Logging safety (dev4)

Protocol diagnostics are redacted at the IMAP seam before any logging target is
invoked.  Generic commands are represented by a safe verb only (`LOGIN`,
`AUTHENTICATE`, `UID FETCH`, etc.); raw command arguments are not exposed.
Message content, header blocks and literal bytes are never diagnostic payloads.
Authentication events contain only mechanism and success/failure.  This remains
true even when callers enable TRACE-level structured logging.

## Mutation semantic safety (dev5)

A successful IMAP APPEND can have application effects beyond passive storage.
Intent-aware APPEND therefore requires a server behaviour profile and explicit
mutation intent.  If the profile's effect does not match that intent, the operation
fails before any command or literal bytes are sent.

In particular, the Citadel profile models Sent APPEND as submission.  `RESTORE` or
`MIGRATE` into Citadel Sent is denied by default; intentional submission uses
`SUBMIT`.  Citadel SMTP is also declared to record Sent automatically, preventing a
client from adding a duplicate Sent copy after SMTP submission.

`MUTATION_PLAN` logging is metadata-only and does not include mailbox names, headers,
message bodies or literals.

## Live mutation qualification gate (dev6)

The APPEND round-trip probe is mutation-capable and therefore requires the exact
environment gate `IMAP_MUTATION_ENABLE=YES`. It refuses INBOX and requires CREATE
of a previously nonexistent mailbox before APPEND. Credentials remain file-sourced
and are never accepted in argv. The probe uses `BODY.PEEK[]` for verification and
retains the test mailbox rather than assuming destructive cleanup semantics.


## Dev7 local index privacy boundary

The NoSQLServer index is a local derived copy of mail metadata and, when enabled, body
search tokens. It can therefore reveal sensitive mail content even though it does not
contain raw MIME bodies. Deployments must protect the index root with the same local
access assumptions as a mail cache. Credentials, app passwords, OAuth tokens and raw
LOGIN/AUTHENTICATE command material are never index fields.

Index search never silently falls back to an unbounded remote BODY fetch. Missing body
coverage is reported as coverage state and repaired by an explicit bounded indexing
pipeline.

## Exact-deletion safety (dev8)

Message deletion is not represented by IMAP `DELETE` (which deletes a mailbox).
A message is removed by setting `\Deleted` and expunging it. Dev8 high-level transfer
code will only perform an exact expunge through `UID EXPUNGE`, therefore requiring
`UIDPLUS`. It never substitutes plain `EXPUNGE`, which could remove unrelated
messages marked by another session/client.

Cross-server transfer never deletes the source merely because APPEND returned OK.
Source deletion is an explicit post-verification commit. A caller that cannot prove
its destination copy should not call `commitSourceRemoval()`.

Special-use destinations are denied by the high-level move helper in dev8. This keeps
vendor behaviours such as Citadel Sent-room submission outside an accidental `mv`.
