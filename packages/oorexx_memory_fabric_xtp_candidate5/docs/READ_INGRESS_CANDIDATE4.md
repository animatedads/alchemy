# Memory Fabric/XTP candidate4: source-side read admission

The new `src/MemoryXtpReadIngress.cls` and `tests/test_read_ingress.rex` add an executable **ingress policy gate**, not a network read protocol or a memory page codec. The native XTP listener is not wired to this gate; no service-origin or identity privilege is asserted from XTP KEY, FIRST, ACK or remote address.

## Contract

- A native listener reports the actual locally admitted canonical service. The gate independently resolves it to its locally configured logical peer and `normal.memory` class. It never accepts a class or physical IP/port from the requester.
- The transport supplies a proof HANDLE. The production authenticator must validate it (e.g. a cryptographic peer/session) and return the authenticated principal. The fixture `TestIngressIdentity` is **not** an authenticator for deployment.
- An independent ACL checks the principal, block, owning provider and exact bounded page range; the fixture `TestIngressACL` is **not** an authorisation provider for deployment.
- The current local `MemoryFabricRegistry` must resolve exact fabric/block/generation and local owning provider with current epoch. Replica offers cannot bypass this source-side owner check.
- Windows are page aligned and limited to 16MiB by default, requests expire within 60s, IDs are bounded to 16–128 safe characters, and 4096 active request IDs are the memory cap before fail-closed refusal.
- Permit `validatePage` repeats authentication, ACL, service binding, expiry, owner and page checks before *each* read and before publication. Revocation or provider reincarnation denies further pages.
- In-process replay guard is a bounded best-effort anti-duplicate aid, not durable storage or a security proof after restart. Reads only; never use it for writes, leases, commits or idempotence guarantees.

## Qualification

- PASS with supplied ooRexx r13196: `rexx tests/test_read_ingress.rex` against Memory Fabric dev10 and Service Descriptors dev1.
- PASS `rexxc src/MemoryXtpReadIngress.cls`.
- NOT YET: authenticated native XTP ingress callback, real crypto/ACL implementations, source-side Operational Capacity Governor admission, cross-process real-page transfer, integrity and receiver commit, service-addressed reliable multicast, ED209 L2/raw36.

No local DMA/shared block bag logic was touched.
