# Memory Fabric over XTP: service and execution boundary

## 1. What changes relative to Storage Fabric

Storage Fabric dev22 implements `storage.range.search` / `storage.range.read`: one multicast discovery intent, two full-range supplier replies and two independent scoped requests, with `normal.storage` governing 30% × 2 / 60%. Memory Fabric should apply **that processing pattern**, not borrow the storage service, object identity or durability guarantees.

Memory request: `(fabricId, blockId, blockGeneration, [startByte,endByte), pageSize, requester/authority)`. Offer: `(logicalPeer, providerId, ownerEpoch, providerGeneration, coverage, evidenceId, admission/expiry)`; this candidate models the first identity/epoch fields but does **not** yet implement signed authenticated offers, expiry or capacity proofs.

Processing sequence:

```text
MI process -> Memory Fabric semantic request (block, generation, pages)
    |
    v
Authoritative Memory Fabric permission / residency lookup
    |
    v
XTP FIRST -> service `memory.block.locate` (service-addressed MULTI: future bridge)
    |        transport service admission before XTP context
    +--> MU5 resident-block offer --> record epoch + evidence
    +--> MU7 resident-block offer --> record epoch + evidence
    |
    v
Registered service `memory.block.read` => `normal.memory`
Operational Planner => max two contexts; <=30% each, <=60% aggregate
Validate provider incarnation, block generation, lease & permission
    |
    +--> XTP FIRST service `memory.block.read` -> MU5
    |         existing XTP KEY/ROUTE context -> aligned pages [0,32 MiB)
    +--> XTP FIRST service `memory.block.read` -> MU7
              independent XTP KEY/ROUTE context -> [32,64 MiB)
    |
    v
Receiver validates per-page versions, checksums and fencing; merge into
Memory Fabric's authoritative destination block; commit only after checks
```

The diagram is the **target transport flow**, not a claim that this candidate dispatches those transfers.

## 2. Proposed canonical services (names provisional until registered)

| Service | Scope | Dispatch semantics / operating class |
| --- | --- | --- |
| `memory.block.locate` | group discovery | XTP reliable multicast after service admission, or authorized unicast/broker discovery until available; discovery is evidence only; `memory.control` |
| `memory.block.read` | request/reply or chunk stream | unicast XTP context, per-context and aggregate percentage, `normal.memory`; page checks and provider revalidation |
| `memory.block.prefetch` | speculative demand | lower priority, cancelable, `memory.prefetch`; cannot displace critical state |
| `memory.block.invalidate` | owner/epoch invalidation | reliable managed fan-out; generation fencing by recipient, not merely by receipt ACK; `memory.critical` |
| `memory.block.lease` | acquire/renew/release | owner-authoritative decision, time/epoch bound; `memory.critical` |
| `memory.block.checkpoint` | staging/restore coordination | memory state boundary and Storage Fabric artifact references; not a Storage Fabric reimplementation; `memory.checkpoint` |
| `memory.block.status` | telemetry/capacity view | aggregated bounded multicast where useful, NEVER authorization proof; `memory.control` |

Services are looked up from the Service Descriptor Registry. **Do not trust a class name or physical endpoint supplied by an untrusted FIRST request.** A service descriptor resolves a logical peer; libxtp selects the qualified L2 (`0x817D`), L3 (`raw36`) or L4 (`udp`) route. No host, port or multicast group appears in a Memory Fabric service descriptor. XTP dev23 currently serializes an Alchemy-specific canonical service descriptor in FIRST under format `0xA11C`. After admission it uses ordinary XTP KEY/ROUTE lookup. The format is an implementation profile, not a claim about standardized XTP 3.4 addressing descriptors.

## 3. Multicast semantics

- Use XTP MULTI for locating resident providers, invalidation announcements and capacity state distribution when an authorized and proven service-addressed MULTI path exists. Avoid N separate discovery requests when one group operation can do the job.
- XTP native multicast supports FIRST+DATA streaming, whole-message go-back-N repair, receiver flow-control feedback (`RSEQ`, `ALLOC`, `RATE`, `BURST`), configured ACK quorum and one-way `NOERR` mode. The application must select the required reliability semantics, not assume one send means all members received it.
- `NOERR` is acceptable only for replaceable observations or advisory hints. Invalidation/lease fencing cannot rely on fire-and-forget delivery or an ambiguous quorum; the authoritative owner epoch and lease fence prevent stale access even if a peer misses a notice.
- A multicast reply advertises *candidate* sources only. It does not convey permission to map memory, create a lease or resolve the authoritative block generation.
- The current dev23 `XtpNamedServiceManager` yields unicast named-service send/listen, while `XtpMulticastSocket` exposes MULTI transport but does not set a named FIRST service descriptor. The class `MemoryXtpDiscoveryPort` is intentionally abstract until this mismatch is resolved and qualified. **No silent multicast-without-service-admission downgrade.**

## 4. Flow control and class policy

Service `memory.block.read` => `normal.memory` registered class. Example NORMAL: `per-context=30`, `parallel=2`, `aggregate=60` relative to the link/class budget. In the provided candidate test, an independent operational policy places `normal.memory` into EMERGENCY suspension, while separately registered `memory.critical` remains admitted for safe invalidation. Production values belong to the estate's Operational Degradation Planner, not hardcoded XTP transport code.

Do not conflate XTP RATE/BURST (receiver transport credit/pacing), XTP SORT/DEADLINE (protocol scheduling priority), and an Operational Planner's percentage-of-link class budget. These are different controls; a live binding must enforce them in the correct layer. The candidate produces exact class budgets. The extracted XTP dev23 `xtp::operational_delay_for_bytes()` exists in the native operational implementation, but is not wired into ordinary named-service `XtpOperationalSocket~send()` as an end-to-end percent-budget limiter. **A planner output saying 30% does not establish transport enforcement of 30%.** In any deployable implementation the receiver admission/semaphore and real send limiter must both be qualified, including concurrent transfers.

## 5. Provider and memory correctness

- Memory Fabric `MemoryFabricRegistry` is authoritative for provider identity, owner epoch, membership and incarnation. A reply from a previous provider generation must be rejected; the candidate's `revalidate()` test proves that on the real registry.
- Check the requested block **generation** against the authoritative block catalog at the receiving service, not simply against the offered claim. Permissions, leases, cryptographic peer identity and evidence expiry remain mandatory and are outside this candidate.
- Read-only replica acquisition may use several current providers. Mutation or ownership transfer must not be inferred from load balancing. Exactly one logical owner/generation authority governs commit, lease acquisition, invalidation and fencing.
- Local shared-memory, native block bag and DMA access stay out of the network path. Remote XTP transfers should use bounded page/window data, zero-copy where legitimately supported, and negotiated filters only when results remain verifiable.
- A received page is not accepted merely because XTP acknowledged it: validate block/generation, page extent, content integrity, owning epoch, recipient authorization and in-flight revocation immediately before publish.
- Place execution at the correct resident MU using Job-to-Node where beneficial; do not confuse migrating execution with remote memory reads. Queue Fabric retains durable work semantics and Memory Fabric does not manufacture a second queue.
- Checkpoint/restore is coordinated with Storage Fabric's durable namespace and existing migratable job boundary; Memory Fabric does not reinvent file durability.

## 6. Carrier paths and failover

1. Local shared memory or DMA for same-machine blocks; no XTP round-trip.
2. XTP L2 on qualified same-Ethernet-domain MI/MU links (EtherType `0x817D`).
3. XTP L3 using protocol 36 across proven permitted paths.
4. XTP-over-UDP where raw36 is filtered or impossible; still XTP service-addressed once qualified.
5. A qualified alternate connector where XTP is not available. No implicit insecure downgrade and no assumption that raw36 timeout proves firewall interference.

Revalidate provider incarnation and transfer generation when routes fail or multipath reconnects. XTP's route generation and Memory Fabric's owner epoch solve different problems; neither substitutes for the other. Existing XTP path health/failover, scheduling, reliable MULTI, RATE/BURST, and multipath are transport-provided capabilities to reuse, subject to exact tested APIs.

## 7. Qualification matrix — 2026-10-16

| Capability | Status | Evidence / missing work |
| --- | --- | --- |
| Real r13196 debug ooRexx interpreter | **LOCAL PASS** | extracted provided .deb, not installed |
| Real Memory Fabric dev10 provider/epoch registry | **LOCAL PASS** | test against registered MU5/MU7 and P7 reincarnation |
| Real named-service descriptor registry | **LOCAL PASS** | class and route-peer derive from canonical registration |
| Real Operational Planner dev2 | **LOCAL PASS** | 30% × 2 / 60%, emergency suspend, separate critical class |
| Memory page/window planning | **LOCAL PASS** | 2 × 32MiB, 2MiB alignment; no remote memory mutation |
| Named XTP FIRST/KEY over loopback UDP | **LOCAL PASS with patch** | native send/listen and registered `memory.block.read`; `xtp_wire_loopback.sh` |
| XTP dev23 reliable multicast | **LOCAL PASS at transport layer** | upstream `test_multicast.sh`; NOT named-service MULTI |
| Named-service multicast discovery | **NOT IMPLEMENTED** | bridge XTP FIRST service admission and MULTI |
| Validated distributed memory ingress / lease authorization | **NOT IMPLEMENTED** | peer auth, owner/lease gate, replica proofs, stale-reply fencing at endpoint |
| Operational percentage pacing on named XTP context | **NOT PROVED** | connect planner budget to real live limiter, validate concurrency |
| Real parallel remote 2-source block transfer/merge | **NOT IMPLEMENTED** | transport page data protocol, checksums and commit |
| ED209 MU/MI L2/raw36/live multicast fabric | **NOT RUN** | host qualification and acceptance evidence required |

## 8. Upstream issues found

XTP dev23 defines routines `xtpNativeListenerOpenServices`, `xtpNativeListenerLastService`, `xtpNativeSendService`, but the ooRexx native routine registration table omits them; the supplied test environment raised `Error 90.999` before the local fix. In addition, `XtpNamedServiceManager~listener` omitted `planner operatingState` in its `expose` statement. `xtp_dev23_native_registry.patch` is a minimal upstream fix, tested locally. This package **does not modify XTP in the Library or merge the patch upstream**.

## 9. Deliberate limitations

The current planner only accepts offers that each cover the *entire* requested window and slices among those complete replicas. It does not yet solve fragmented/overlapping partial coverage, erasure-coded reconstruction, large variable-size working sets, dynamically arriving offers, retransmit resume, provider removal mid-transfer or lease expiry. Do not treat it as a distributed-memory I/O implementation. It is an additive, executable boundary and policy qualification increment that can be merged into Memory Fabric after XTP service/multicast, live pacing, and receiving-end authority are proven.
