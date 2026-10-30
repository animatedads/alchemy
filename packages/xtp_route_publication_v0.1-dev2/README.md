# XTP route publication and commissioning — v0.1-dev2

Architecture: Tom Dyer. New ooRexx ingress slice: ChatGPT GPT-6, 29 Oct 2026.

The `xtp.provision` service is a DHCP-like, operator-authorised *configuration publication* mechanism. It is neither DNS nor the XTP ROUTE/XROUTE endpoint-exchange wire field. This package builds on candidate1's genuine offline Ed25519/quorum validator ; dev2 supplies a native ooRexx `XtpProvisionIngress` **fail-closed read/admission gate**. It is NOT the route actuator, LDAP implementation, full commissioning service or proof of ED209 field deployment.

## Current implementation

- `src/XtpProvisionIngress.cls` checks the real `XtpSession~info` contract: service `xtp.provision`, context `OPEN=1`, `PROTECTION=encrypt`, nonzero 16-hex `KEYID`. It asks a trusted, externally supplied identity resolver to prove that the key belongs **exclusively** to one MI principal, is for this service and has a current **fence** from LDAP or a signed-file fallback. A shared service key alone cannot identify an MI. All absent/mismatched evidence refuses admission.
- `~receive(session)` reads a single XTP EOM-delimited request with configurable byte/frame/time bounds and aborts on malformed/oversized/timeout/peer-close, while retaining the authorised principal for later policy checks. This object does NOT interpret JSON or dispatch any effectful opcode, by design.
- `tests/test_ingress.rex`: deterministic native test using injected fake session and resolver; **tests the gate only**, not libxtp, LDAP, or actual cryptography.
- The previously published `xtp_route_publication_v0.1_candidate1` remains the independent offline Ed25519/quorum reference; it is not copied into this source package.

## Exact dependency boundary

- XTP `packages/oorexx_xtp_v0.1-dev34/rexx/XtpSession.cls`, session `info`, `read`, `lastFlag`, `abort`. XTP session must be opened with protection `encrypt` or a sticky service profile requiring encrypt; caller cannot choose weaker protection.
- `packages/oorexx_xtp_v0.1-dev34/rexx/XtpServiceKeys.cls` and `XtpLdapKeySource.cls`: per named-service keys sourced first from owned LDAP Identity Directory + Secret Broker, with root-owned mode 0600 file fallback. **Their per-service shared key by itself is not an exclusive MI key**; the trusted resolver is NOT delivered here.
- Actual trust evidence must bind XTP session key ID to an exclusive MI principal and enrolled service policy, and include a durable revocation/epoch fence. A generic LDAP bind or source IP is insufficient.
- The existing Service Descriptor Registry still controls operational class; the caller cannot self-promote. The gateway owns actual route mutation, and a separate sealed snapshot/atomic activation is required.

## Reproducible tests

`REXX_BIN=/path/to/rexx ./tests/run.sh` against ooRexx 5.3.0 r13196.
Run candidate1 separately for its 19 offline Ed25519/quorum tests (requires Python cryptography); those tests are **not** bundled into dev2.

For service activation, the gateway must supply a **real** `XtpSession`, a privileged resolver tied to Identity Directory, a signed/quorum-verified controller allocation, a write-before-memory ledger, and atomic CONFIG_PREPARE/ACTIVATE/REVERT IPC. Those are not implemented here. No field or live LDAP integration claimed.
