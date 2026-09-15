# Migratable Job integration

QueueRexx v0.1-dev12 binds the exact supplied Migratable Job v0.2.4. The main migration API remains `migratable.job/0.2`; standard starter API remains `migratable.job.start/1`; v0.2.4 adds managed initial-placement API `migratable.job.placement/1` and audit receipt API `migratable.job.placement.receipt/1`. QueueRexx does not implement a second migration coordinator, placement allocator, receipt store, or migration state machine.

## Authority boundary

```text
QueueBash / QueueRexx filesystem -> QID and queue state
WLU Authority                    -> work/WLU-s reservation and settlement
Job-to-Node Allocator            -> placement, admission, ownership fencing
Storage Fabric                   -> verified resumable checkpoint movement
Queue Fabric                     -> migration commands + retained live status
Execution runtime                -> safe-point pause/checkpoint and restore/resume
Migratable Job                   -> start/placement receipts + planned handoff coordination/provenance
```

Migration never creates a second authoritative QueueBash record.

## Standard starter contract

Migratable Job owns `migratable.job.start/1` and its durable digest-protected start receipts. One contract normalizes NEW, RECOVER and HANDOFF. `startId` is claimed durably before runtime side effects; retry is answered from the durable receipt; conflicting reuse fails closed.

`QueueRexxMigratableStarterApplication` remains the direct-starter compatibility guard for NEW. It holds the shared QID lock, requires exactly one authoritative `running` record, calls workload `startNew()`, and releases the lock on normal or exceptional exit. It does not own receipts, RECOVER or HANDOFF.

## Managed initial placement — v0.2.4

For migratable NEW jobs, the preferred frontage is `MigratableJobManagedPlacementTool` / `migratable.job.placement/1`:

```text
PLAN             advisory eligibility/ranking
CHECK            verify the exact current Job-to-Node lease
ALLOCATE         authoritative Job-to-Node allocation
START            verify exact current lease, then enter standard starter
ALLOCATE_START   allocate + start; failed/ambiguous start retains placement
RELEASE          explicit placement release
```

The application definition is the source of the native `JobPlacementRequest`. QueueRexx does not persist or recreate a shadow lease. If the same current verified lease already satisfies the same request, the framework may return `PLACED_REPLAY`. Failed or ambiguous start deliberately remains `START_FAILED_PLACEMENT_HELD` until explicit release.

QueueRexx adds two narrow adapters around this upstream authority:

1. `QueueRexxMigratableStartIntentStore` atomically persists only the exact NEW-start invocation (`queuerexx.migratable_start_intent.v1`) before authoritative allocation. It stores no placement verdict, ownership epoch, capability generation or allocator state. After restart it reconstructs the same `MigratableJobStartRequest`; changed intent fails closed.
2. `QueueRexxPlacedStartExecutor` implements the v0.2.4 placed-start executor seam. It reacquires the shared QID lock, requires the queue record still to permit NEW execution, applies the QueueRexx execution-policy gate, then calls Job-to-Node `verifyLease()` again using the application definition's exact placement request before invoking `migratable.job.start/1`.
3. Optional `QueueDurableJobNodeAllocator` (package `QueueRexxJobNodeDurable.cls`) presents the v0.2.4 tool with a durability-preserving Job-to-Node allocator surface. It delegates allocation/renew/release/checkpoint/restore to v0.6 `JobNodeDurablePlacementManager` and current-lease verification to the underlying allocator. QueueRexx requires a successful restore pass before placement mutation, including on an empty journal. It stores no alternate ownership decision.

The durable Job-to-Node journal lives under the QueueRexx queue-root logs tree and inherits queue-root ownership. A qualified restart discards the original allocator, ownership registry, managed tool and application objects; v0.6 restores the same allocator sequence and ownership epoch, QueueRexx reloads the exact NEW intent, v0.2.4 returns `PLACED_REPLAY`, and the standard starter receipt prevents a second workload entry. Explicit placement release is checkpointed and is not resurrected by a later restore.

That second verification deliberately closes the selection-to-launch race. If Job-to-Node evidence changes after the managed-placement tool's outer check but before runtime entry, QueueRexx refuses launch. Placement remains framework/Job-to-Node authority and is explicitly releasable; QueueRexx does not silently discard it.

`QueueRexxManagedPlacementFacade` exists only to make the NEW intent durable before ALLOCATE/ALLOCATE_START and to require an exact persisted intent before START/RELEASE. Every placement operation itself delegates to the upstream managed-placement tool.

## Remote Job-to-Node authority over the QueueRexx mesh — dev12

A migratable workload does not need a local allocator when its QueueRexx node is a client of a designated QueueRexx authority node. The general `queuerexx.peer.mesh/0.1` relationship owns node connectivity/trust/routing; the semantic placement protocol is the exact supplied `job.node.allocator.network/0.1` implementation from `job_node_allocator_v0.6-network1`.

```text
FD / workload QueueRexx node
    exact JobNodeNetworkAllocatorClient
              |
      QueueRexx peer service route
              |
       queue.transport/2
              |
QueueRexx authority node
    exact JobNodeNetworkAllocatorService
              |
       JobNodeAllocator v0.6
```

`QueueRexxJobNodeNetworkAllocatorProxy` is deliberately thin: it adapts the exact upstream network client to the allocator-shaped surface expected by `MigratableJobManagedPlacementTool`; it owns no lease codec, placement state, ownership epoch or replay ledger. No client-local allocator fallback is permitted if the network authority is unavailable.

For remote START, Migratable Job first performs its exact managed-placement CHECK. `QueueRexxPlacedStartExecutor` then acquires the normal QID lock and performs a **second remote network1 CHECK** immediately before invoking `migratable.job.start/1`. Network failure, authorization failure or stale lease evidence therefore means no private-worker start. Starter receipt replay still suppresses duplicate runtime entry.

The qualified encrypted path proves `PLAN -> ALLOCATE -> CHECK -> RENEW -> START -> replayed START -> RELEASE` over one QueueRexx peer relationship, with the private worker entered exactly once.

## Shared queue state during migration

The one shared record remains `running` while the framework transfers execution ownership. QueueRexx uses the normal per-QID lock around pause/checkpoint and destination resume, and revalidates immediately before resume that exactly one authoritative record exists and is still running. An ordinary cancel/fail/complete transition using the same lock therefore wins cleanly and blocks late resume/commit.

## Retained status subscription

Migratable Job v0.2.4 retains topic schema `migratable.job.status/1` introduced in v0.2.2. QueueRexx uses `QueueMigrationStatusSubscriber` as a consumer, not a publisher. Each subscriber has its own ordinary Queue Fabric queue and accepts only monotonically newer migration-local `sequence` values. Retained replay for late subscribers is supported.

Live status may defer unsafe local stale inference, but it cannot authorize resume, cancel, ownership change, queue transition, WLU settlement, first-start replay, placement or migration commit.

## Status projection

`QueueJobStatusProjector` exposes durable and live status separately and classifies `durable_only`, `live_only`, `in_sync`, `live_ahead`, `durable_ahead`, migration-ID mismatch and same-sequence state conflict. The durable side is serialized with `authoritative=true`; retained/live status is `authoritative=false`. Optional WLU projection is another read model only.

## WLU across placement and migration

WLU is tied to placement authority, not to one local PID. The real WLU reservation identifier is carried in Job-to-Node `reservationRef`. QueueRexx generic WLU scheduling verifies current Job-to-Node placement directly; migratable NEW execution uses v0.2.4 managed placement. Neither path manufactures a parallel entitlement object. Source pause or destination resume does not settle WLU; settlement belongs to terminal job lifecycle through WLU Authority.

## Liveness and failure safety

During active migration, a dead or paused source process alone is insufficient stale evidence. Destination `RUNNING` migration state is also not blindly treated as local PID liveness. QueueRexx preserves provenance and returns deferred/unknown evidence where authority is incomplete.

Runtime adapter, starter guard and placed-start executor conditions release the QID lock before propagation. QueueRexx does not swallow framework failures, synthesize a migration/placement commit, or relaunch a NEW execution after durable starter/placement replay says it already ran.
