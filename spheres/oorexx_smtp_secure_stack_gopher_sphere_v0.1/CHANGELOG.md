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
