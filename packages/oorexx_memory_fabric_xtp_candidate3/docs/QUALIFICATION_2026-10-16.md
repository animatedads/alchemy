# Local qualification evidence — 2026-10-16

Artifacts (SHA-256):

- ooRexx 5.3.0 r13196 debug `.deb` (provided): `8add57fd2463403c9e91f3f49856e3f61b34753938abab3a617fc8063d2df4ae`
- XTP dev23 source: `defd8f9aa4088079bb40bec4d87dfa41464913923175ce3f4946ce6f2a5c77c2`
- Memory Fabric dev10 source: `91a05494c86ce7627f7a010af182c167701b5bf1f8ce2d93c99cda9d992644d8`
- Storage Fabric dev22 source: `167fc431fdbe2c5ecd613911d26b253c87bbc5b4ae226b304e12d21ce1ccfc6c`

Runtime was **extracted**, not installed, into an isolated container folder. XTP dev23 native binding was rebuilt using locally patched `xtp_rexx_native.cpp` and the dev23 archive's `libxtp.a`; the XTP source patch has been dry-run-verified against pristine dev23 archive sources.

Executed tests (exit 0):

```text
PASS Memory XTP planning: 2x30/60, aligned slices, fencing and REAL named-service registry/manager
PASS real ServiceDescriptor + Operational Planner dev2 memory class and scoped capacity
PASS real ooRexx XTP named-service send 16
PASS FIRST service name and control bytes over real XTP/UDP loopback
PASS named XTP service FIRST admission and delivery
PASS multicast route is explicit and excluded from unicast best-connect
PASS reliable XTP MULTI transaction, wire filters and acknowledgement quorum
PASS multicast replay reaches a receiver that appears after initial transmission
PASS XTP MULTI NOERR one-way mode
PASS reliable multicast fails closed when receiver quorum is not reached
PASS XTP MULTI FIRST+DATA stream reassembles a binary payload
PASS segmented multicast stream replays after receiver absence and delivers once
```

The final seven lines were produced by XTP dev23 `tests/test_multicast.sh` and test native reliable MULTI separately from the Memory integration candidate. They **do not** demonstrate a service-admitted XTP MULTI invocation, a remote block/page fetch, concurrency-rate enforcement or live ED209 mesh communication.

Known limits: only complete-replica window offers; page-window planner is NO_DISPATCH; receiver-side memory block authorization/lease checks, source evidence authentication, native per-context percentage enforcement and service-addressed multicast are not implemented. No claim of production acceptance.
