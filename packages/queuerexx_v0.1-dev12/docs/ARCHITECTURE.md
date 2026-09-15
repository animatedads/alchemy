# QueueRexx architecture

## 1. Identity

QueueBash discovered and hardened the operational semantics. QueueRexx encodes those semantics as objects, provider contracts, event flows, and recovery-safe transitions.

The two runtimes share one authoritative queue fabric:

```text
QueueBash  --->  .queuebash filesystem  <---  QueueRexx
                      ^
                      |
               authoritative state
```

A QueueBash-created job must be readable and operable by QueueRexx, and a future QueueRexx-created job must be readable and operable by QueueBash without conversion.

## 2. Compatibility kernel versus providers

QueueRexx deliberately splits behaviour into two layers.

### Compatibility kernel

The kernel owns invariants and providers may not bypass it:

```text
QueueRoot
QueueRecord
QueueIdAllocator
QueueStateStore
QueueStateLock
QueueTransitionService
QueuePolicyCoordinator
QueueEventCoordinator
QueueRecoveryManager
QueueProviderRegistry
QueueSchemaRegistry
```

The kernel is responsible for the QueueBash filesystem schema, QID uniqueness, ownership, locks, atomic state transitions, policy-before-launch ordering, event commit ordering, duplicate reconciliation, and recovery rules.

### Providers

Providers answer *how* a capability is supplied on this platform for this job. Examples:

```text
RunnerProvider
PlatformFactProvider
PlacementProvider
PolicyProvider
ProcessObservationProvider
CloudProvider
RemoteAdminProvider
ServiceFactProvider
VcsProvider
PlanProvider
GovernanceProvider
```

A provider can launch, observe, terminate, query, or explain according to its contract. It cannot rename a job between QueueBash state directories directly.

This is the key architectural replacement for QueueBash's shell `if`/`case` capability trees: the semantics stay; capability realization becomes registered polymorphism.

## 3. Provider selection pipeline

Selection is evidence-bearing and deterministic:

```text
QueueRecord
    |
    v
QueueJobRequirement  <---- class/policy constraints
    |
    +------------------ QueuePlatformFacts
    |                         |
    v                         v
QueueProviderRegistry ---> eligible providers
                              |
                              v
                       provider selector
                              |
                              v
                    QueueProviderDecision
```

The decision records the requested capability, candidates, support/denial reasons, scores, selected provider, and any compatibility fallback.

For runners the QueueBash 0.18.144 behaviour is the initial authority:

- explicit `direct` -> direct when supported;
- explicit `systemd` -> systemd only; unavailable/foreign-user cases fail rather than silently switching;
- `auto` -> systemd when the current user's systemd service is genuinely usable, otherwise direct;
- root launching another Unix user -> direct compatibility path;
- unknown legacy runner token -> current QueueBash compatibility fallback to direct, but with explicit QueueRexx evidence.

## 4. Observation is provider-specific

There is no universal `PID => live` rule.

A runner provider ultimately returns a typed observation such as:

```text
LIVE
DEAD
UNKNOWN
LAUNCH_PENDING
```

The transition/recovery kernel decides what those observations permit.

Examples inherited from QueueBash 0.18.144:

- Direct runner: live `RUN_PID` **or** a live member of `RUN_PGID` is live evidence.
- systemd runner: recorded `SYSTEMD_UNIT` plus `ActiveState`/`SubState`/`MainPID` is authoritative; `RUN_PID` is not authoritative when it is merely the `systemd-run` client.
- systemd state unknown/unqueryable -> `UNKNOWN`, therefore defer rather than stale-interrupt.
- fresh running record without `RUN_PID`/`RUN_PGID` inside the launch window -> `LAUNCH_PENDING`, therefore defer.

This distinction is why liveness belongs to runner providers while stale-state mutation belongs to the kernel.

## 5. 0.18.144 atomicity invariants

The following are QueueRexx kernel rules, not provider options:

1. Pending QID allocation uses exclusive/no-overwrite creation and bounded retry.
2. One QID may have one authoritative live state.
3. State mutation requires a per-QID lock.
4. Transition source is revalidated after lock acquisition.
5. State move is an atomic rename on the shared filesystem.
6. Fresh/incomplete launch metadata is deferred, not declared stale.
7. Unknown liveness is deferred, not guessed dead.
8. Known stale health/sentinel/policy duplicates are archived, never silently deleted.
9. Operator cancellation/deletion authority is not automatically undone by recovery.
10. Ambiguous evidence results in `manual_review`, not destructive repair.

## 6. Event commit order

QueueRexx is event-driven, but events follow state authority rather than replacing it.

For state-changing operations the intended order is:

```text
acquire QID lock
  -> validate source record and policy
  -> provider operation as applicable
  -> atomic filesystem transition / metadata commit
  -> append QueueBash-compatible event
  -> commit derived indexes/observations
  -> schedule durable triggers
release QID lock
```

A failed sidecar update cannot roll back or reinterpret a successfully committed QueueBash filesystem state. Sidecars repair by replay/rebuild.

Triggers never mutate queue files directly. A trigger submits a command/request back through the QueueRexx kernel.

## 7. Recovery-safe triggers

A trigger firing model needs at-least-once recovery without duplicate effects. The target design uses:

```text
event_id
trigger_id
claim/lease
last committed event cursor
idempotency key = trigger_id + event_id
outcome/audit record
```

The Object Queue Fabric already supplies durable queueing and trigger concepts; Runtime Registry supplies pinned executable generations. QueueRexx should use those rather than inventing another callback runtime.

Direct in-process callbacks may be useful for non-durable diagnostics, but durable operational triggers should be registry-backed/pinned and replay-safe.

## 8. Sidecar doctrine

QueueRexx may exploit richer ooRexx infrastructure while preserving identical QueueBash files:

```text
.queuebash/                  authoritative, shared contract
~/.queuerexx/ or service DB derived/rebuildable QueueRexx acceleration state
```

Sidecars may include SQL indexes, trigger registrations/cursors, Queue Fabric durable queues, Observation streams/checkpoints, crypto seals, and provider discovery caches.

The queue must still be inspectable and recoverable from QueueBash authority if every sidecar is lost.

## 9. Object lifecycle

A future primary worker path is intended to look like:

```text
QueueKernel.open(root)
  -> QueueRecord.load(qid)
  -> PolicyCoordinator.assess(record)
  -> JobRequirement.fromRecord(record)
  -> PlacementProvider.select(...)       [optional remote placement]
  -> RunnerProvider.select(platform, job)
  -> QueueTransition.claim(...)
  -> RunnerProvider.prepare(...)
  -> RunnerProvider.launch(...)
  -> RunnerProvider.observe(...)
  -> QueueTransition.complete/fail(...)
  -> EventCoordinator.publish(...)
```

The CLI is intentionally thin and is never the owner of business logic.


## 10. First-class WLU lifecycle

QueueRexx v0.1-dev8 adds Work Load Units as a separate authority composed with queue state, placement and migration. A managed job declares expected work, ceiling work, target duration and WLU/s delivery capacity.

A managed job is staged in `waiting` with the QueueBash-visible `QUEUEREXX_WLU_HOLD` class. `waiting` alone is not sufficient because QueueBash sentinel may reevaluate it; the failing class preflight is the compatibility fence.

The execution path is:

```text
shared WLU declaration
  -> WLU Authority reservation (ceiling + WLU/s)
  -> Job-to-Node placement with reservationRef
  -> QueueRexx activation under QID lock
  -> running
  -> usage metering under QID lock
  -> terminal queue transition + WLU settle/release
```

Queue state and WLU accounting are deliberately not described as one atomic store. QueueRexx persists WLU terminal intent before the queue transition and recovers the missing external-authority close after a crash. QueueBash terminal state remains authoritative if another engine commits it first.

See `WLU_INTEGRATION.md`.

## 11. Projected status is not authority

QueueRexx projects durable Migratable Job state, retained `migratable.job.status/1` live snapshots and optional WLU reservation state into one read surface while preserving their provenance. Durable/live divergence is explicit (`in_sync`, `live_ahead`, `durable_ahead`, etc.). No projected state may directly authorize mutation.

## 12. Release progression

### v0.1-dev1 — read-only compatibility foundation

- native non-evaluating QueueBash job reader;
- exact shared list JSON object model;
- runner-provider registry and evidence-bearing selection;
- mandatory stock structured-data classes.

### v0.1-dev2 — typed health/observation parity

- class-owned numeric queue-state and job-observation constants;
- direct/systemd runner observations;
- bounded health scan and duplicate diagnosis;
- Observation v0.5 adapter.

### v0.1-dev3 — recovery-safe mutation kernel

- exclusive pending reservation and QueueBash-compatible per-QID locks;
- compare-and-move transition service;
- PREPARED/COMMITTED/EVENT_RECORDED journal phases;
- deterministic crash recovery and mixed-engine race qualification.

### v0.1-dev4 — exact Migratable Job authority binding

- exact supplied migration objects/adapters, no parallel state machine;
- same QID remains `running` across planned handoff;
- QID lock/revalidation around pause/checkpoint and destination resume.

### v0.1-dev5 — typed admission and accelerated SHA-256

- typed submit/worker-admission API surfaces;
- explicit fail-closed operation policy;
- Foreign Runtime/OpenSSL preferred through normal Crypto `.SHA256`;
- exact mixed QueueBash record/execution compatibility.

### v0.1-dev6 — QueueBash 0.18.144 and retained migration status

- lock-tree/reconciliation ownership parity;
- typed permission failure versus contention;
- PID start-cookie/foreign-host stale-lock hardening;
- non-mutating `diagnose`;
- retained `migratable.job.status/1` subscriber queues.

### v0.1-dev7 — first-class WLU and composed status

- WLU-managed staging with QueueBash-visible hold fence;
- WLU Authority + Job-to-Node `reservationRef` integration;
- activation/usage/terminal WLU lifecycle under QID lock;
- crash-safe settlement/release and cross-engine terminal recovery;
- durable/live migration + optional WLU status projection.

### v0.1-dev8 — WLU-aware scheduling and typed execution

- WLU/placement-aware scheduling as eligibility/capacity, with ordinary queue priority retained as ordering authority;
- direct/systemd runner `prepare/launch/observe/terminate` behind provider dispatch;
- PREPARED launch intent plus durable provider locators before runtime metadata is trusted;
- atomic append of QueueBash-compatible runtime metadata while preserving unknown fields;
- durable exit evidence drives done/failed; dead-without-exit remains ambiguous;
- crash reconstruction after provider launch but before metadata commit;
- typed cancellation requires conclusive DEAD evidence before the shared record moves;
- mixed QueueBash cancellation of QueueRexx-started work remains authoritative.

### next — execution policy/provider breadth and public pilot

- bind the remaining QueueBash class/default/security/sandbox/resource-control surfaces into provider preparation;
- add runtime guards/resource controls around launched payloads;
- qualify real systemd-user execution on an appropriate host in addition to deterministic backend tests;
- expand execution recovery around node loss/migration handoff;
- only then consider a deliberately limited public submit/run/cancel pilot.

Public worker/daemon mutation remains disabled in dev8 even though the internal execution API is executable and qualified.

## 13. Domain constants and OO dispatch

QueueRexx deliberately does not translate Bash string-comparison trees into ooRexx string-comparison trees. Fixed semantic values belong to their owning classes. For example, filesystem `running` is converted to `.QueueState~RUNNING` at the boundary; health/recovery logic then compares the numeric class constant. Observation behaves the same way with `.QueueJobObservation~LIVE`, `~DEAD`, `~UNKNOWN`, and `~LAUNCH_PENDING`.

Boundary spellings remain class-owned constants so QueueBash compatibility is exact. Behavioural variation should normally be handled by provider message dispatch rather than testing provider-name strings. See `DOMAIN_CONSTANTS.md`.


## Dev12 network authority and peer mesh

QueueRexx dev12 adds two distinct network surfaces over one Queue Fabric runtime:

```text
                     QueueRexx node
                          |
             +------------+-------------+
             |                          |
 job.node.allocator.network/0.1   queuerexx.peer.mesh/0.1
             |                          |
 exact JobNodeAllocator v0.6      local authority adapters
 placement/admission/ownership    approval/job/policy/load/...
             |                          |
             +------------+-------------+
                          |
                Queue Fabric v0.9-dev5
                   queue.transport/2
```

The Job-to-Node network API exposes one exact allocator authority. The peer mesh instead carries evidence between independent QueueRexx authorities. It has no leader and no mandatory transit node. Each decision supplies its own fixed threshold/required-peer policy, so topology failure does not become an accidental global stop and cannot silently reduce a high-risk quorum. See `PEER_MESH.md`.

