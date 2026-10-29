# Memory Fabric protected read ingress — XTP dev34

Status: tested ooRexx adapter against real Memory Fabric dev10 / Service Descriptors dev1, with a **test-only XtpNamedAcceptedSocket fixture**. Production XTP dev34 protected-listener-to-Memory-Fabric execution is **NOT QUALIFIED**, and no real memory page-data transfer is claimed.

## Why dev34 changes the contract

XTP dev34 (`packages/oorexx_xtp_v0.1-dev34`) provides per-service AEAD-protected named messages over L2/raw36/UDP and exposes the native listener's `XtpNamedAcceptedSocket~serviceName`, `~protection`, `~keyId`, and `~keyPrincipal`. `XtpServiceKeys~list` reports registered keys without exposing secrets; their authoritative source is LDAP/Identity Directory through Secret Broker, with tightly controlled fallback. XTP does not confer Memory Fabric block/lease/ACL authority.

## New source

- `src/MemoryXtp34ProtectedRead.cls::MemoryXtp34ReadWire` implements a strict bounded `MFXR1` request frame; binary-safe block/fabric identity uses hex, and numeric ranges reject signs, exponent notation, oversized values and extra fields. No requester identity, service, route or operational class is accepted in the wire format.
- `MemoryXtp34ReadBridge~admitReceived(nativeAcceptedSocket, trustedNowMs)` requires the actual native accepted-socket type and a locally configured service, encrypted transport, a complete bounded frame, and an existing local Memory Fabric ingress gate. It uses the service name **reported by XTP**, not caller-provided payload.
- `MemoryXtp34KeyAuthenticator~identityFor(nativeAcceptedSocket)` rejects clear, authenticate-only, wrong service, unknown key, key/principal mismatch, expired key, revoked key, file-fallback key, missing key state, invalid time and missing native protection metadata. It consults a **live** trusted `XtpServiceKeys~list` on each Memory Fabric authorization and each page-validation call; the existing block-owner-epoch, generation and ACL checks remain mandatory.

The `keyPrincipal` identifies the authenticated XTP service key, **not necessarily a unique machine or human**. Production must provision per-MU/MI identities in the estate Identity Directory and scope memory-read ACLs accordingly; do not share the same principal across unrelated instances. LDAP binds/authentication and HTTPS service deployment are external authorities, not reimplemented here.

### Use by the native server

1. Configure and refresh XTP service keys from the approved Identity Directory and Secret Broker; require `encrypt` for `memory.block.read.<MU>`. Do not allow a clear fallback, even when LDAP is unavailable or a key expires.
2. Open an XTP named-service listener for the locally registered read service. Use the actual XTP 34 `accept()` result, not a synthetic object from untrusted code.
3. Supply the service's `XtpServiceKeys` and a trusted Unix-epoch-second clock to `MemoryXtp34KeyAuthenticator`. The clock used by `MemoryXtpReadIngress` itself is trusted Unix-epoch-milliseconds. Do not use a caller's timestamp.
4. Supply the authenticator, current `MemoryFabricRegistry`, `ServiceRegistry`, and *real* principal/block/range ACL implementation to `MemoryXtpReadIngress`.
5. `MemoryXtp34ReadBridge~admitReceived` returns a permit or `.nil`. For each page, call `permit~validatePage` immediately before reading and again before publishing bytes. There is no page publisher in this candidate.

## Security limitations and acceptance gates

- XTP dev34 documents a **cross-listener replay window** for one-way protected messages if another listener shares the same key. This adapter has only process-local replay tracking. Use per-instance keys and service-specific ACLs. A durable or shared replay record is required before claiming cross-MU pooled exactly-once admission. No write/lease/commit operation may rely on this guard.
- Multipath protected transfers are present in dev34, but are not used by this ingress adapter; the native listener callback and page response writer remain unimplemented. Multicast in dev34 still lacks named-service/group-key protection. Memory Fabric multicast discovery must not transmit confidential data or bypass service/key ACLs.
- XTP named-service route ownership remains XTP's; Memory Fabric retains block identity, epoch fencing and placement decisions, and local DMA/shared-block transport is unchanged.
- Independent test to do: use a real XTP34 native listener/LDAP key table and two ooRexx processes; reject wrong-service, wrong principal, expired and revoked key, rogue clear FIRST/DATA, replay, stale block, and unequal provider epochs. Then qualify L2 (`0x817D`), raw protocol 36 and approved UDP fallback over ED209 MU↔MI paths.
- Test fixture `tests/fixtures/XtpSocketProvider.cls` is intentionally excluded from all production paths. The external XTP runtime dependency must resolve to **dev34 or later with the exact accepted-socket/key metadata contract**; unresolved `::requires` fails the deployment.

## Local evidence

With supplied ooRexx 5.3.0 r13196, real Memory Fabric v0.1-dev10 and Service Descriptors v0.1-dev1:

`tests/run_protected_read_bridge.sh` — PASS (synthetic accepted-socket and key directory, real registry and service objects).

`rexxc src/MemoryXtp34ProtectedRead.cls` — PASS.

This is an incremental protected **read admission path**, not a completed remote memory-page service or evidence of on-wire protection in this package. The XTP dev34 upstream local security results are separate and cannot substitute for integrated Memory Fabric qualification.
