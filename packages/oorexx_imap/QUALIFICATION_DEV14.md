# IMAP 0.1-dev14 — selected-feed revocation fence

Architecture: Tom Dyer. Code, test, evidence: ChatGPT GPT-6, 5 November 2026.

Change: re-evaluate ImapMailboxAuthority for IMAP_SELECT before reading each selected-mailbox change batch, including NOOP and IDLE. A principal revoked after SELECT must not receive unsolicited EXISTS/FETCH/EXPUNGE notifications. In IDLE the endpoint emits BYE [ALERT] selected mailbox access revoked and stops.

Runtime: user-provided ooRexx 5.3.0 r13196. Original dev13 plus regression test fails as expected at revoked poll (rc=1). Corrected dev14 test_revocation_feed.rex passes (NOOP and IDLE paths), and 23/23 required tests pass. This test uses an injected revocable mailbox authority, not a live LDAP connection.

NOT QUALIFIED: real LDAP/LDAPS revocation propagation from IdentityDirectory, multi-process durable change feed, 200,000-message scale, external IMAPS interoperability, complete IMAP4rev1 conformance, deployment. This is a single-process authorization recheck, not an atomic directory+message read revision fence.
