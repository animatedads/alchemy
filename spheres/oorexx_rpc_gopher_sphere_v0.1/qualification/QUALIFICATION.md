# Qualification ledger — RPC Invocation sphere v0.1

**Scope:** 2026-10-23 documentation candidate, not an executable RPC release.

## This turn — locally executable documentation checks

- Archive/member SHA-256 provenance computed from **the local exact source ZIP bytes**, stored in `SOURCE_ARCHIVES.json`.
- `python3 tests/verify_sphere.py`: structure, article reachability, required boundaries, JSON parse/schema consistency, provenance SHA shapes, manifest checksum coverage.
- `python3 tests/verify_sphere.py --archive-root /mnt/data`: optional deep hash verification for all five ZIP artifacts, including documented member digests.
- Gopher binary not available locally during authoring: do not call this Gopher VALID/CLEAN until independent LLM Gopher validation executes.

## Historical source evidence (NOT executed by this sphere)

| Component | Package-reported evidence | Limitation |
| --- | --- | --- |
| RPC Core dev1 | 27 registry tests + 5 shared-protocol tests under r13196 | No production concurrency or network authentication |
| JSON-RPC dev3 | 36 core + 18 selector + 20 framing + 6 TCP + 9 instrumentation tests | No externally authenticated production endpoint |
| SOAP dev2 | 40 SOAP + 6 serialization + 6 shared selector tests | No live SOAP HTTP/TLS or full WSDL/XSD support |
| gRPC dev3 | 15 native HTTP/2 streaming fixture tests | Native ooRexx stream bridge not qualified; inbound and bidi missing |

## GitHub source receipt gate

RPC Portfolio source candidate: `oorexx_rpc_portfolio_v0.1-dev1.zip`, SHA-256 `c07d87ebfdaf988ad9a4c2a4e52a8927da29b4e40365fbc7bd0fd544fa7a66fc`. Submitted Git commit: `93f34ef7b2781d9a7567fd730b0d9fafb58f9920`. An Autobuild receipt was **not** observed when this sphere was authored; promotion to `main` is unconfirmed. Do not convert branch presence into accepted runtime qualification.

## Remaining formal sphere gates

1. LLM Gopher `sphere validate` => VALID; `sphere lint` => CLEAN.
2. `context rpc-invocation --full` => OPENED; `search registration` => FOUND.
3. Autobuild integration tests PASS, source published to versioned path, matching receipt and accepted branch commit.

## HTTPS ingress source addition 2026-10-29
- Static source contract checks PASS 14; eight named runtime test fixtures supplied but unexecuted.
- ooRexx runtime unavailable in packaging environment; LDAP dev22 authentication and HTTPS server dev8 live integration **PENDING**.
- No HTTPS/Rasen Falcon deployment or completed field test is asserted.
