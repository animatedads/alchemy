# IMAP dev13 source recovery and mail-service qualification — 2026-11-04

Architecture: Tom Dyer. Recovery, qualification and Git submission: ChatGPT GPT-6.

## Exact source provenance

- Immutable source: ChatGPT Library `oorexx_imap_v0.1-dev13.zip` (uploaded 2026-10-09).
- Archive SHA-256: `a1666062755700196b09a8ad7bd4f16adc7e1f6810c75322ee70cfa3a3e31737`.
- `SHA256SUMS` within recovered archive: 84/84 entries verified. Archive has 85 regular files (85th is SHA256SUMS).
- All 85 regular files were transferred into the Git candidate without re-authoring; comparison of Git object SHA-1 and executable bit with original ZIP contents: **85/85 EXACT MATCH**.
- One pre-existing Git-only `ALCHEMY_SOURCE_PROVENANCE.md` is preserved; it is not part of the recovered ZIP.

## Fresh local runtime tests (not production)

- Interpreter: user-supplied Open Object Rexx 5.3.0 r13196 internal debug build.
- `tests/run.sh`: **22/22 required PASS**.
- With Socket Provider v0.1-dev14, Storage Fabric v0.1-dev23 and Instrumentation Mesh v0.1-dev8 staged: **5/5 additional PASS** (`test_socket_provider_server`, storage adapter/projection, instrumentation adapter/IDLE).
- Other optional suites (API Client + Foreign Runtime, NoSQL index, Logging, Socket Isolation Telemetry) **NOT_RUN** in this pass.
- IMAPS external-client conformance, live TLS/LDAP Bind integration, persistent multi-process mailbox change feed and 200k-message scale **NOT_RUN**.

## SMTP compatibility checkpoint

- Original Library source `oorexx_smtp_secure_stack_v0.1-dev11.zip` recovered.
- Exact archive SHA-256: `95bf988357505e2ab59ec3264d702e9179c99be530cb55248647cf23ac3229bc`.
- `run_tests.sh` on r13196 with Socket Provider dev14, Instrumentation Mesh dev8, Storage Fabric dev23: **PASS**, including 9 signature/relay/inbox classification policies, Access Permissions, MAS/MAIL, S/MIME signer/verifier, wire fixture, durable delivery, dispatcher, Socket Provider binding and SMTP-001/002/003 protocol regressions.
- The first attempt without the dependency path failed because `SocketProvider.cls` was missing; after staging Socket Provider, a later run lacked `StorageFabric.cls`. The full staged run then passed. Neither earlier failure demonstrates a protocol defect.
- Foreign Runtime and RPC Service Core/ConnectSelector optional integration were not staged; this is **not live STARTTLS or remote SMTP qualification**.
- SMTP dev11 remains a Library source baseline; GitHub SMTP dev7.1 PR #101 must be reconciled separately. **This IMAP submission does not modify SMTP sources.**

## Security and operational gates

- SMTP owns verified/signed -> `INBOX` and unsigned/invalid -> `INBOX-UNSIGNED` delivery classification; IMAP may not manufacture either membership.
- LDAP Bind establishes identity only. Require active IdentityDirectory principal plus explicit `MAIL_READ` before mailbox access. `EMAIL_SEND` is separate SMTP submission authority; signed mail alone does not grant it.
- LDAP-owned LDAPS daemon is on PR #71; service activation and dependency closure remain separate from this IMAP source promotion.
- No production installation, listener, certificate, DNS, firewall, host, credentials or operator cutover is claimed.
- Do not advertise IMAP4rev1 until grammar, interoperability, recovery and conformance are independently qualified.

## Release action

Merge this source-recovery PR only after review. Keep service deployment and live acceptance gated independently.
