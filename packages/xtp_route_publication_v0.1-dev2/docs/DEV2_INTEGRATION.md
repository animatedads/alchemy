# XTP provisioning dev2: execution and safety boundary

Date: 2026-10-29. Architecture: Tom Dyer. Coding: ChatGPT GPT-6.

## New capability

Native ooRexx `XtpProvisionIngress` receives one bounded message from a protected named-service session *after* checking session metadata and asking a trusted Identity Directory resolver to bind its key to a single authorised MI. The code passes deterministic native r13196 tests. No socket binding is embedded: real libxtp sessions are consumed through the official dev34 XtpSession surface; no XTP transport files were edited.

## Why this gate matters

- XTP dev31 session support removes the persistent-context gap reported for dev25.
- XTP dev32–34 provide per-service encryption/authentication, automatic key source LDAP/file fallback, and security fixes. Pin dev34; dev33 protected-message defects are not acceptable. Use sessions, not one-way messages, for quorum/control lifecycle.
- A key with owner `service:xtp.provision` may be present on multiple nodes. It authenticates possession of the *service* key, **not** which MI made a publication. Therefore admission must refuse missing or nonexclusive principal binding and cannot assume one principal from KEYID without a stronger enrollment policy.
- The recommended next XTP owner interface is a session-bound authenticated peer principal / key generation identity with a durable revocation epoch. Until delivered, an external trusted resolver with explicit exclusive policy is mandatory; plain KeyID mapping to a shared service key must fail.

## Intentionally denied operations

No ANNOUNCE/REQUEST/ALLOCATE processing, no route-file writes, no service class edits, no live advertisement, no LDAP search or secret loading are performed. A received payload is bytes only, not authorised action. Caller must independently check canonical JSON, Ed25519 signatures, controller membership/quorum, target realm, lease, sequence, policy and snapshot root; then a privileged gateway installer must stage and commit atomically without replacing bootstrap access. Use the candidate1 reference verifier as negative vectors, NOT as an ooRexx production signature verifier.

## Required owner work before ED209 promotion

1. Qualified per-node XTP principal/key binding or client-owned key sets (D-07); the XTP owner is being consulted via Rasen Falcon REQ-00001829.
2. Identity Directory dev22 policy adapter returning exact `OK`, `EXCLUSIVE`, `KEYID`, `SERVICE`, `PRINCIPAL`, `AUTHORITY`, `FENCED` from trusted, current session binding; not from incoming payload or a caller-created structure.
3. Durable authority/quorum record and atomic two-registry XTP gateway activation; protect pinned seed paths.
4. Real XTP session exercises (UDP, raw36, L2 as supported) with ED209 access through sshnode.sh and CAP_NET_RAW only as needed. Existing local tests do not qualify those paths.
