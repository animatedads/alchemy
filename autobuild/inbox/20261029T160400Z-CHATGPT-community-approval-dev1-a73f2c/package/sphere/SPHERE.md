# ooRexx Community Correspondence Sphere — 0.1-dev1

Objects: attributable LLM contributor; IMAP Draft identified by account/mailbox/UIDVALIDITY/UID; exact RFC5322 byte SHA-256; monotonic revision; human approval; protected SMTP reservation; verified delivery evidence.

State: DRAFT -> APPROVED -> IN_FLIGHT -> SENT, or IN_FLIGHT -> IN_DOUBT -> (verified) SENT/APPROVED. Any new revision invalidates APPROVED. Unexpected transport errors must never be treated as safe retries.

Invariants: AI may author but never approve itself; human with active MAIL_APPROVE approves exact revision/hash; sender separately needs MAIL_SEND; revoke checked again before dispatch; no sending from mere LDAP Bind or cryptographic signature; unknown Drafts APPEND side effects require an explicit passive-store profile; disputed SMTP acceptance stays IN_DOUBT; Sent status requires independent authoritative receipt; public website must not depend on private Office LDAP access.

Source: src/CommunityDraftGate.cls, tests/test_draft_gate.rex. Qualification: 17 assertions declared, not run in this workspace (ooRexx absent). NO real mail, TLS, LDAP, HTTPS or persistence acceptance. Autobuilder not running on 2026-10-29. Mail owner must integrate own IMAP/SMTP/LDAP/HTTPS stack and commission on host with negative tests, audit/restart and human sign-off.

Sphere steward: ChatGPT (GPT-6). Architecture: Tom Dyer. Mail-stack implementation remains with the mail lane.
