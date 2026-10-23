# Memory Fabric / XTP dev25 — engineering boundary and acceptance matrix

The Memory Fabric XTP candidate2 adapter adds enforced transport-capacity *control* to the Memory Fabric dev10 planning prototype. The current source does not encode/decode Memory Fabric pages or mutate a remote block.

## Source and authority split

| Authority | Owned semantics |
| --- | --- |
| MemoryFabricRegistry dev10 | block ID/generation, one currently published owner, epoch, provider incarnation, block length |
| Independent replica verifier (injection required for replicas) | cryptographic or separately authorised statement proving another provider's block-generation replica and valid region; merely naming an evidence ID does not count |
| ServiceDescriptor dev1 | canonical name, locally registered operational class, logical XTP route peer |
| OperationalCapacityGovernor dev5 | capacity domain, tickets, admitted contexts and aggregate class percentage, state refresh/reconcile |
| XTP dev25 native socket | named-service FIRST, KEY/ROUTE contexts, XTP carrier routing and per-context `capacityRate` |
| Storage Fabric dev23 | durable namespace/backing/verification, independent of Memory Fabric volatile residency |
| Job-to-Node / Queue Fabric | portable execution placement and durable job transport/status; not implemented here |

The example: 64 MiB aligned window; two independently verified suppliers; normal.memory 30% per context, maximum two, aggregate 60%. The candidate2 planner now shrinks its context count when aggregate cannot hold the proposed independent shares. `MemoryXtpCapacityAdmission~admit()` rechecks every slice and obtains governor tickets. Any failed admission releases previously acquired tickets. Sending validates recipient peer/class against local ServiceDescriptor, rechecks the block and ticket, requires native `capacityRate`, then sends **at most 64 KiB** of opaque caller-supplied control bytes.

**Security note:** XTP transport ACK, service name and replica evidence ID are NOT authentication or memory ownership. dev25 native named-service listener permits admission by name, but caller identity and page-level ACL/lease authorization still require an authenticated ingress service above XTP. No protected production operation is authorised by this package. `MemoryXtpAuthority~current` uses `resolveBlock` for one owner and an injected verifier for other replicas; the supplied verifier in tests is synthetic. Do not use it in production.

**Multicast note:** `XtpNamedServiceAddress~multicast` is false in dev25. XTP MULTI is separately implemented and qualified for packet-group transport; group membership does not implement `memory.block.locate` service-level authentication or durable confirmation. Candidate2 does not pretend to implement group-scoped service multicast; this remains a gated next increment. L2 EtherType 0x817D, raw36 and XTP-over-UDP are transport capabilities; only local UDP loopback was tested here.

## Qualification evidence (23 October 2026)

- PASS: `tests/test_capacity_admission.rex` MemoryFabricBlockRef owner authority, reject unverified replicas, injected trusted-replica fixture, source-class/peer checks, Governor dev5 two tickets/60%, 300000→150000 B/s capacity update, emergency suspension and recovery, revoked proof, provider reincarnation, released tickets, aggregate shrink.
- PASS: `tests/test_memory_xtp_admission_wire.sh` true separate ooRexx processes using native `liboorexx_xtp_native.so` dev25, two XTP named FIRST control messages (60 KB), native rate pacing: 0.201346 s and 0.401289 s.
- PASS: XTP dev25 `make test-service test-capacity-rate test-auto-key` (native named FIRST, ooRexx manager scope, 200 ms UDP pacing, auto key allocation).
- PASS: inherited candidate1 `tests/run.sh`, `tests/xtp_wire_loopback.sh` against updated dev25/dev5.
- PASS: `tests/test_contract_static.py`, `bash -n` scripts, and ooRexx `rexxc` syntax.
- NOT RUN: ED209 network and real authenticated/multicast memory page movement, peer replica cryptographic verification, full Gopher `VALID/CLEAN`, dynamic conformance with future Memory Fabric dev11 and newer.

## Remaining work — no hidden completion claim

1. Introduce a real signed/authorised replica-attestation provider; reject stale clocks/expiry, wrong job, generation, block region and foreign security domains.
2. Register scoped Memory multicast service interest groups and prove named-service ingress semantics with XTP MULTI, duplicate filtering, explicit application-level ACK population and repair/late join; no unqualified multicast sends.
3. Implement native bounded remote *page* transfer with per-page proofs, integrity checking, lease/epoch fence before effectful mutation, safe cleanup and retention of fast local shared/DMA block bags.
4. Bind capacity tickets to authenticated receiver ingress, test two real concurrent sockets, stalled/zero-capacity cases, aggregate contention across Memory/Storage and emergency transitions.
5. Qualify real ED209 MI↔MU L2, MU↔MU raw36, fallback UDP and policy-driven carrier changes. Record environment-specific evidence, not inferred reachability.
6. Activate/validate the companion Gopher sphere with canonical Gopher tooling and register it in the project authority catalogue after review.
