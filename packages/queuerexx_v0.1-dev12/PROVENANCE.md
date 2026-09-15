# QueueRexx v0.1-dev12 provenance

Dev12 is based on the sealed QueueRexx v0.1-dev11 package and is qualified against the exact supplied authority/transport baselines below. QueueRexx composes, but does not fork, the supplied `job_node_allocator_v0.6-network1` codec, access policy, durable request ledger, allocator service and allocator client; the general QueueRexx peer mesh supplies shared connectivity/routing while exact JobNodeAllocator v0.6 retains placement/admission/ownership authority.

```text
QueueRexx v0.1-dev10 sealed executable base
SHA-256 800350d6554a5c7ab18aee53def8de367395f6167cb5bf5001510e52ca3dd479

QueueBash 0.18.144 BOB27 lock-tree ownership hotfix full delivery
SHA-256 004182da577100df4249c1d993c6ffe2baf611e8f52fb5a4fd672aa71613caae

Migratable Job v0.2.4
API migratable.job/0.2
Starter API migratable.job.start/1
Managed placement API migratable.job.placement/1
Placement receipt API migratable.job.placement.receipt/1
SHA-256 c6cfadcd64ad9f803eea14e37854021ef7eae2015a1c54dcc3c799c04f1517df

2026-09-14 ooRexx API bundle
SHA-256 8fd06ee75eeb8726327c19157e5f929cd08f64aa512e20c4449ffe7fb928c404

2026-09-14 supplied sphere collection (continuity/reference input)
SHA-256 a586d09799437a35432861e5b0548de1ec6e273abc689ac013b50fd8f7165245

Open Object Rexx 5.3.0 r13196 user-supplied debug build
SHA-256 8add57fd2463403c9e91f3f49856e3f61b34753938abab3a617fc8063d2df4ae
```

## Dev12 authority-server and peer-mesh provenance

```text
QueueRexx v0.1-dev11 sealed base
SHA-256 257f8c3aab344aeb6d812d3162be6c4ede2e086ec06093e687e1b14f4afdd255

Job-to-Node Allocator v0.6 / job.node.allocator/0.6
SHA-256 58f23b90824d73b584ea5bfce4ac5805a537ab0283508ee6c81ccf2458f80ead

Job-to-Node network extension v0.6-network1 / job.node.allocator.network/0.1
SHA-256 e6ea65304f51e16ee336a27783d185b09cdfff7117b4abe8ed8afabe2cb03b1f

Queue Fabric v0.9-dev5 / queue.transport/2
SHA-256 05b3cbc92aff353dc3a44eb0373d7efb1e49a5e81071892b410a8b8f63fa2262

Work Load Units v0.12 / work.load.units/0.12
SHA-256 b5f6cd8230daa26c227b93032d42b4263c5fcb3b40838359aeab3421cf0ab75a

Migratable Job v0.2.4 / migratable.job/0.2
SHA-256 c6cfadcd64ad9f803eea14e37854021ef7eae2015a1c54dcc3c799c04f1517df

Alchemy Objects v0.8
SHA-256 7683ed56ea99097226ea2f13f73305fb49919ba2ec822df2253ccfff59c6c073

Crypto v0.8.3
SHA-256 5ebcab81493287499719f98920cb190d37afc79992cb34c7772d5392f63b9b49

Foreign Runtime v0.22.6
SHA-256 25a7b258b7920c355b96f19807515d6fb6e419687714396589b054a7029ab465

Runtime Reference v0.4
SHA-256 c42a0c51cc5f5e26056d22db97d53eae2633141a7cebe3304b5f19b1847f957a
```

QueueRexx dev12 does not fork Job-to-Node placement rules or Queue Fabric transport. `QueueRexxAuthorityStack` hosts the exact v0.6 allocator and delegates network `ALLOCATE/CHECK/RENEW/RELEASE` to it. `QueueRexxPeerMeshRuntime` composes permanent direct queues/channels and authenticated `queue.transport/2` endpoints using the exact Queue Fabric implementation.

The peer mesh is not a cluster authority database. Each peer retains its local queue/policy/JTN/WLU authorities. Mesh responses are authenticated evidence from those authorities. A durable per-peer request ledger supplies replay/conflict semantics; fixed decision policy remains local to the requesting QueueRexx authorization transaction but is embedded in each peer request digest so it cannot be weakened during replay.


## QueueBash policy-provider provenance

Dev11 adds no new policy language and does not fork QueueBash class-policy or authorisation semantics.

`QueueBashClassPolicyProvider` invokes the exact supplied QueueBash 0.18.144 `_queue_job_policy_execution_check` implementation. For read-only assessment it copies the authoritative job record to a temporary file first. Any QueueBash exemption annotations therefore land only on the temporary assessment copy.

The provider is compatibility-pinned to QueueBash 0.18.144 and fails closed if the source is unavailable or reports another version. Shared/admin policy precedence, command-block rules, standing grants and command-bound authorisation validation remain owned by QueueBash.

`QueueBashExecutionPolicyGate` is an adapter from that verdict into QueueRexx typed worker admission. It does not move queue files. A denied claimed job becomes `pol_blocked` only through `QueueTransitionService` under the existing queue-state authority model.

Typed QueueRexx submission remains fail-closed in dev11 because `QueueSubmitRequest` does not yet model the complete QueueBash submit-time security/policy surface.

## Work Load Units provenance

QueueRexx dev11 continues to bind the Work Load Units implementation supplied through the exact API bundle:

```text
API work.load.units/0.12
WorkLoadUnits.cls SHA-256 ed68e7f1b3003e5bf8aa2ecf586f4b8e52b52596fde2d9e2d73f1b9f21a78b29
Job-to-Node Allocator v0.6 / job.node.allocator/0.6
SHA-256 58f23b90824d73b584ea5bfce4ac5805a537ab0283508ee6c81ccf2458f80ead
```

QueueRexx does not fork either authority. WLU Authority owns work entitlement, WLU/s throughput capacity, reservation proof, measured consumption and settlement/release. Job-to-Node owns placement/admission, current ownership fencing, capability/capacity evidence and lease validity, and carries the exact WLU reservation identifier in `reservationRef`.

Dev11 removes the prior scheduling shortcut in which a matching `reservationRef` could be treated as adequate placement evidence. `QueueJobNodePlacementAuthority` delegates to the exact supplied v0.6 allocator `verifyLease()` using the original `JobPlacementRequest`; QueueRexx does not reproduce requirement digests, generation checks, admission restoration or ownership rules. Missing/stale evidence fails closed.

For generic non-migratable WLU scheduling, the in-memory request/lease lookup remains only a qualification helper and is not represented as durable placement authority. For migratable NEW jobs, v0.2.4 makes the application definition the source of the native placement request and supplies authoritative managed placement; QueueRexx therefore does not invent a second durable placement-intent/lease protocol.

The dev10 QueueBash-to-WLU bridge converts an already compatible QueueBash record into the existing QueueRexx WLU admission/staging model; it does not create a parallel job format or mint independent work entitlement.

## Migratable Job provenance

The supplied Migratable Job v0.2.4 package is not bundled or forked by QueueRexx. QueueRexx binds its migration state, execution-adapter, commit-authority, retained-status, standard starter and managed-placement contracts.

The starter owns durable digest-protected `startId` receipts, CLAIMED-before-side-effect ordering, replay/conflict detection, RECOVER and HANDOFF. The v0.2.4 managed-placement layer additionally owns PLAN/CHECK/ALLOCATE/START/ALLOCATE_START/RELEASE orchestration over Job-to-Node, audit receipts, `PLACED_REPLAY` for the same verified lease, and explicit placement retention/release around failed or ambiguous starts.

`QueueRexxMigratableStartIntentStore` persists only the canonical NEW invocation under the queue root before authoritative allocation. It is restart evidence for what QueueRexx asked the framework to start; it does not persist a placement verdict, lease, ownership epoch, capability generation, allocator policy generation or admission proof. The application definition remains the source of the exact native `JobPlacementRequest`.

`QueueRexxManagedPlacementFacade` delegates every placement operation to the upstream managed-placement tool. `QueueRexxPlacedStartExecutor` is the v0.2.4 placed-start seam: it takes the shared QID lock, rechecks QueueRexx queue/policy authority, invokes Job-to-Node `verifyLease()` again against the definition request, and only then delegates to `migratable.job.start/1`. This second verification closes the selection-to-launch race without transferring placement authority to QueueRexx.

`QueueRexxJobNodeDurable.cls` is an optional integration package, not a replacement allocator. `QueueDurableJobNodeAllocator` delegates durable allocate/renew/release/checkpoint/restore to Job-to-Node v0.6 `JobNodeDurablePlacementManager`, delegates lease validity to the underlying v0.6 allocator, requires successful restore before mutation, and repairs journal ownership to match the queue root. The durable journal is Job-to-Node state: QueueRexx does not reinterpret its lease, ownership epoch, allocator sequence or WLU admission snapshot.

The earlier `QueueRexxMigratableStarterApplication` remains a direct-starter NEW guard for callers that use `migratable.job.start/1` without managed placement. It does not own starter receipts or migration recovery. RECOVER/HANDOFF remain framework-owned.

The framework authority split remains intact: Job-to-Node owns placement/admission/ownership fencing; Storage Fabric owns verified resumable checkpoint transfer; Queue Fabric owns command/transport delivery; execution runtime owns safe-point pause/checkpoint and restore/resume; commit authority is explicit and fail-closed; Migratable Job coordinates placement/start/handoff/provenance.

The same QueueBash QID record remains queue-state authority throughout migration.

## Status-topic provenance

Migratable Job v0.2.4 retains `migratable.job.status/1`. QueueRexx is a subscriber only: each observer uses its own ordinary Queue Fabric queue and accepts only monotonically newer migration-local `sequence` values.

`QueueJobStatusProjection` preserves durable and retained/live views separately. The retained topic remains non-authoritative observation; it cannot authorize transitions, start replay, resume, cancel, WLU settlement, placement change, or migration commit.

The internal provider identifier `migratable-job-status-topic-v0.2.2` is intentionally retained as the adapter-lineage identifier for the unchanged status protocol introduced in v0.2.2; it is not the declared Migratable Job package baseline.

## Crypto provenance

QueueRexx does not ship or fork SHA-256. It calls the supplied Crypto `.SHA256` public API. For throughput-sensitive qualification, QueueRexx installs the supplied Crypto Foreign Runtime provider; Runtime Reference selects `foreign.openssl.crypto` for `crypto.sha256.digest/1` through the supplied Foreign Runtime/OpenSSL bridge. Pure ooRexx SHA-256 remains fallback.

WLU v0.12 owns its own high-frequency reservation proof contract and uses the supplied Crypto implementation. QueueRexx does not substitute another proof format.

## Typed execution and runtime recovery provenance

QueueRexx adds no replacement process/runtime authority. Direct/systemd runner providers use host mechanisms behind OO contracts and a recovery-safe execution journal while the shared QueueBash record remains queue-state authority.

`QueueRuntimeMonitor` and dev10 fleet recovery are read/recovery orchestration over the existing queue record, execution journal, provider evidence and durable exit locators. Recovery may request reconciliation only through `QueueExecutionService`; it cannot move queue files directly or bypass WLU terminal authority. Missing/contradictory evidence remains deferred or manual-review.

## Provider telemetry / trigger provenance

Dev10 provider-health telemetry and Observation projection are read models. They do not gain execution, queue or placement authority.

Durable trigger evidence provides registration/firing/replay bookkeeping only. Trigger actions request normal QueueRexx transitions through established mutation services; trigger persistence is not a direct queue-state mutation mechanism.

## Dev12 authority-server composition

QueueRexx dev12 authority networking is composed against exact Job-to-Node Allocator v0.6 authority semantics and Queue Fabric v0.9-dev5 `queue.transport/2`. Migratable Job baseline is exact v0.2.4. QueueRexx does not replace placement/ownership semantics with a new network authority; the network service delegates mutation and verification to Job-to-Node and adds ACL, routing, durable request replay and service orchestration.
