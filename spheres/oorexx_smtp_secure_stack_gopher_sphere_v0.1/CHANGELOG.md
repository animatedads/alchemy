# Changelog

## 0.1

Initial SMTP Secure Stack sphere.

Grounded in the qualified `oorexx_smtp_secure_stack_v0.1-dev11.zip` delivery and the repository package publication. Captures signed-relay authority invariants, Storage Fabric/Queue Fabric durability boundaries, recipient-safe outbound dispatch semantics, RPC-over-SMTP composition, Instrumentation Mesh privacy/correlation rules, and exact qualification provenance.

## 2026-10-29 — dev7.1 protocol hotfix

- Fixed the remaining post-final-DATA cleanup hole on the current Git dev7 line.
- QUIT/close syntax exceptions after a definitive final reply can no longer manufacture a retryable transport failure.
- Added `tests/review_cleanup_exception.rex` covering both QUIT and close exceptions after remote `250`.
- Recorded LDAP PR #71 consumer contract: active attributed IdentityDirectory principal plus explicit MAIL_READ/EMAIL_SEND; Bind/signature alone confer no send authority.
- Autobuilder is not running; dev11 remains the last complete r13196 qualification baseline.


## 2026-11-04 — dev7.2 restart-safe mail storage

- Made SMTP metadata commit authoritative and atomic; a metadata failure can no longer return durable delivery success.
- Added atomic Storage Catalogue checkpointing through a temporary file.
- Made mailbox membership idempotent across retry/replay.
- Added mailbox object enumeration/count/reload APIs for IMAP and mail-service consumers.
- Added restart regression proving catalogue reconstruction, mailbox enumeration, envelope restoration and byte-identical RFC822 reload.
- Autobuilder remains stopped; this is committed source/readiness evidence, not a new full-runtime qualification.
