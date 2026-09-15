# Changelog

## 0.1-dev12 — general QueueRexx peer mesh + exact Job-to-Node network authority

- Retained `queuerexx.peer.mesh/0.1` as the general QueueRexx-to-QueueRexx node fabric over Queue Fabric v0.9-dev5 `queue.transport/2`: named peers, permanent request/reply/xmit queues, sender/receiver channels, authenticated socket endpoints, durable routing and restartable configuration.
- Added service-neutral `QueueRexxPeerMeshRuntime~bindServiceRoute()`, allowing multiple logical services to reuse one authenticated peer relationship rather than opening independent private RPC stacks.
- QueueRexx now hosts the **exact** `job_node_allocator_v0.6-network1` implementation (`job.node.allocator.network/0.1`) as an authority service carried by that mesh. QueueRexx does not fork or reimplement the upstream network codec, request ledger, access policy, allocator service or allocator client.
- `QueueRexxAuthorityStack` owns lifecycle/recovery composition for exact JobNodeAllocator v0.6, `JobNodeDurablePlacementManager`, WLU admission recovery, exact `JobNodeNetworkRequestLedger`, exact `JobNodeNetworkAccessPolicy`, exact `JobNodeNetworkAllocatorService`, and shared Queue Fabric transport.
- FD / Migratable Job clients use the exact upstream `JobNodeNetworkAllocatorClient` for `PLAN / ALLOCATE / CHECK / RENEW / RELEASE`; there is no workload-local allocator fallback. `QueueRexxJobNodeNetworkAllocatorProxy` is only a thin allocator-shaped adapter for Migratable Job composition.
- Split configuration into general peer connectivity/trust (`queuerexx.peer.mesh.config/1`) and Job-to-Node semantic client bindings (`queuerexx.job-node.authority-peer-clients/1`). Host/port/transport keys are not duplicated in the authority-service document.
- Preserved server-owned reply routing: network requests cannot nominate arbitrary reply queues. Client ACL constrains operations and optional `ownerNodeId`.
- Authority restart restores Job-to-Node durable state before accepting mutating network work, drains durable pre-crash requests before listen, preserves exact request-id replay/conflict semantics, and leaves responses queued for temporarily offline peers rather than turning delivery failure into authority rollback.
- Qualified WLU-backed authority restart: network ALLOCATE creates the real WLU reservation, Job-to-Node restart restores ownership plus authenticated admission evidence, and remote CHECK verifies the reconstructed lease.
- Qualified one encrypted QueueRexx peer relationship carrying both ordinary peer-mesh `HEALTH` and exact network1 `ALLOCATE/CHECK/RELEASE` traffic over `queue.transport/2`.
- Qualified full remote Migratable Job v0.2.4 flow over the mesh: PLAN -> ALLOCATE -> CHECK -> RENEW -> START -> replayed START -> RELEASE, with Migratable Job lease verification plus a second remote CHECK under the QueueRexx QID lock immediately before `migratable.job.start/1`; the private worker enters exactly once.
- Re-ran the unchanged upstream `job_node_allocator_v0.6-network1` in-process replay, durable-ledger restart and encrypted two-process socket qualifications successfully.
- Diagnosed prior apparent socket hangs as slow pure-Rexx crypto fallback caused by an incorrect `QF_CRYPTO_FOREIGN_BRIDGE` value; the qualified path uses the Foreign Runtime/OpenSSL bridge JSON and remains independently covered by crypto fallback tests.
- Public job mutation CLI remains disabled; dev12 exposes qualified authority/server and internal integration surfaces without silently enabling end-user `submit`, `run`, `cancel`, `migrate` or `daemon`.

## 0.1-dev11 — policy authority + Job-to-Node verification + Migratable Job v0.2.4 managed placement

- Added `QueueBashClassPolicyProvider`, a concrete `QueuePolicyProvider` bound to the exact QueueBash 0.18.144 worker execution gate.
- Policy evaluation runs against a temporary copy of the authoritative `.job` record, so read-only inspection cannot append exemption metadata or otherwise mutate queue authority.
- Added read-only `queuerexx policy-check QID [--json]` with schema `queuerexx.policy_assessment.v1`.
- Added `QueueBashExecutionPolicyGate` for internal typed worker admission. The provider returns policy evidence only; `QueueTransitionService` remains the sole authority that moves a denied claimed job to `pol_blocked`.
- Qualified QueueBash shared/admin class-policy precedence, blocked command words and QueueBash-created command-bound authorisations without reimplementing QueueBash authorisation validation in ooRexx.
- Added fail-closed behavior for missing QueueBash source, QueueBash compatibility-version mismatch, non-running execution assessment, and duplicate-QID queue authority.
- Typed submission deliberately remains fail-closed: dev11 binds worker execution policy only and does not infer QueueBash submit-time policy semantics from an incomplete `QueueSubmitRequest`.
- Hardened WLU scheduling so `reservationRef` equality is necessary but no longer sufficient: the exact retained `JobPlacementRequest` is rechecked by Job-to-Node v0.6 `verifyLease()` before the job becomes eligible.
- Added typed Job-to-Node verification evidence and fail-closed results for missing allocator/time authority, missing placement request, QID mismatch, stale/superseded placement, lost admission restoration, capability/capacity generation drift, ownership fencing and lease/capacity expiry.
- Reworked the WLU scheduling qualification to mint its lease through the real Job-to-Node allocator with WLU admission and ownership registry instead of hand-constructing a placement lease.
- Kept generic non-migratable WLU placement conservative: `QueueMemoryPlacementLeaseLookup` remains an in-process qualification helper, so public remote/fleet execution is still disabled.
- Updated the migration baseline to exact Migratable Job v0.2.4 (`migratable.job/0.2`), retaining `migratable.job.start/1` and binding new managed placement API `migratable.job.placement/1` plus `migratable.job.placement.receipt/1`.
- Added `QueueRexxMigratableStartIntentStore`, persisting only the canonical NEW-start invocation before managed allocation; it deliberately stores no shadow placement lease or allocator authority.
- Added `QueueRexxManagedPlacementFacade`, which delegates PLAN/CHECK/ALLOCATE/START/ALLOCATE_START/RELEASE to upstream v0.2.4 while requiring durable exact NEW intent around authoritative allocation/start/release.
- Added `QueueRexxPlacedStartExecutor`; under the shared QID lock it rechecks queue and policy authority and calls Job-to-Node `verifyLease()` a second time immediately before entering the standard starter.
- Qualified restart reconstruction with `PLACED_REPLAY`, exact-intent mismatch rejection, starter replay, terminal queue-state refusal, `START_FAILED_PLACEMENT_HELD`, explicit RELEASE and a race where Job-to-Node evidence changes between the outer managed-placement check and final runtime entry.
- Added optional `QueueRexxJobNodeDurable.cls` / `QueueDurableJobNodeAllocator`, delegating mutation to Job-to-Node v0.6 `JobNodeDurablePlacementManager`; a restore pass is mandatory before allocation/renew/release/verification, and the journal inherits queue-root ownership.
- Qualified full allocator-object reconstruction: Job-to-Node restores allocator sequence, ownership epoch and active placement, QueueRexx reloads only the exact NEW intent, v0.2.4 returns `PLACED_REPLAY`, starter replay suppresses a second runtime, and durable RELEASE is not resurrected on another restart.
- Qualified WLU-backed Job-to-Node restart using the real QueueRexx WLU admission adapter: the authenticated WLU reservation proof is reconstructed from Job-to-Node durable state, the restored lease verifies, execution settles WLU, and explicit placement release survives restart.
- Reran the complete upstream Migratable Job v0.2.4 suite unchanged, including its new managed-placement tests plus all v0.2.3 starter/migration/storage/Queue Fabric/status regressions.
- Public mutating CLI remains disabled. Dev11 adds policy inspection and qualified internal placement/start authority composition; it does not enable public `submit`, `run`, `cancel`, `migrate`, `daemon`, or recovery mutation.

## 0.1-dev10 — provider telemetry, durable trigger/fleet recovery, WLU bridge and standard migration starter guard

- Added typed provider health telemetry plus read-only `queuerexx provider-health`, retaining provider observation as evidence rather than queue authority.
- Added Observation v0.5 projection for provider telemetry without coupling Observation delivery to execution decisions.
- Added durable, idempotent trigger registration/firing with restart replay and transition-only mutation requests.
- Added bounded fleet runtime recovery over the dev9 runtime relation/action model; reconciliation still delegates to `QueueExecutionService` and ambiguity remains deferred/manual-review.
- Added QueueBash-record to WLU v0.12 staging/admission bridge while preserving the existing shared job format and WLU/Job-to-Node ownership boundaries.
- Requalified the exact QueueBash 0.18.144, WLU v0.12, Job-to-Node v0.6, Observation v0.5 and typed execution contracts under ooRexx 5.3.0 r13196.
- Updated migration baseline to Migratable Job v0.2.3. The main API remains `migratable.job/0.2`; the new `migratable.job.start/1` contract standardizes NEW/RECOVER/HANDOFF start entry with durable digest-protected receipts and fail-closed replay/conflict handling.
- Added `QueueRexxMigratableStarterApplication`: a thin NEW-execution decorator that holds the ordinary shared QID lock, requires exactly one `running` QueueBash/QueueRexx record, delegates the workload start, releases on propagated conditions, and leaves receipts/replay/RECOVER/HANDOFF to Migratable Job.
- Reran the upstream Migratable Job v0.2.3 suite unchanged, including crash-after-claim replay, conflict rejection, RECOVER, HANDOFF, destination bridging, receipt-integrity fail-closed, durable layout, Storage Fabric transfer, Queue Fabric dispatch and retained status.
- Public mutation remains disabled; dev10 expands qualified internal/API behavior and read-only inspection only.

## 0.1-dev9 — provider-aware runtime projection and restart reconciliation

- Added read-only `QueueRuntimeMonitor` combining QueueBash queue authority, immutable execution journal phases, provider-specific observation, runtime metadata and durable exit evidence.
- Added class-owned `QueueRuntimeRelation` and `QueueRuntimeAction` constants; monitoring code no longer branches on ad-hoc status strings.
- Added deterministic classification for missing launch metadata, missing journal evidence, execution-id mismatch, multiple active intents, provider unavailability, durable-exit pending reconciliation, provider-deferred observation and dead-without-exit ambiguity.
- Added bounded read-only `queuerexx runtime-status QID [--json]` and `queuerexx runtime-scan [--json]`.
- Added internal `QueueRuntimeRecoveryManager`; it delegates mutation only to the already-qualified `QueueExecutionService~reconcile()` when the read model recommends deterministic reconciliation.
- Qualified restart recovery after launch-before-metadata without relaunch, durable-exit-to-terminal recovery, and terminal QueueBash authority preservation.
- Public recovery and all existing public mutating CLI commands remain disabled.

## 0.1-dev8 — WLU-aware scheduling and recovery-safe typed execution

- Activated runner provider `prepare/launch/terminate` mechanics behind `QueueExecutionService`; providers still have no queue-state mutation authority.
- Added PREPARED/LAUNCHED/METADATA_RECORDED/TERMINAL_RECORDED execution journal phases and durable PID/exit/systemd-unit locators.
- Added real direct provider execution with separate process groups, durable exit evidence, atomic QueueBash-compatible runtime metadata, terminal reconcile and crash reconstruction after launch-before-metadata failure.
- Direct launch uses a non-capturing system executor for background payloads; launch identity is communicated through the durable PID locator, avoiding ooRexx captured-pipe lifetime coupling.
- Added POSIX-portable process-group termination and zombie-aware Linux PID/PGID observation.
- Typed cancellation now requires provider `DEAD` evidence after terminate before moving the shared record to `cancelled`; unconfirmed stop leaves queue authority unchanged.
- Added deterministic systemd execution-provider qualification with injected platform facts and fake backend/probe, including MainPID liveness and unconfirmed-stop refusal.
- Added `QueueJobScheduler`, WLU-aware scheduling admission and `QueueTypedWorker`; WLU gates capacity/eligibility while normal queue priority remains ordering authority.
- Added real WLU reservation + Job-to-Node placement -> typed activation -> direct execution -> WLU settlement end-to-end qualification.
- Added real QueueBash 0.18.144 cancellation of QueueRexx-started direct payload with QueueRexx terminal reconciliation preserving QueueBash authority.
- Public mutating CLI remains disabled.

## 0.1-dev7 — first-class WLU lifecycle and projected runtime status

- Added first-class QueueRexx WLU job requirements using Work Load Units v0.12 / `work.load.units/0.12`: expected work, ceiling work, target duration and requested WLU/s.
- Added QueueBash-safe WLU staging. Managed jobs use `waiting` plus the reserved `QUEUEREXX_WLU_HOLD` class and preserve their requested class in `WLU_ORIGINAL_JOB_CLASS`; real QueueBash 0.18.144 sentinel/reevaluation cannot promote the hold.
- Added exact WLU Authority + Job-to-Node integration. QueueRexx reserves the full work ceiling and delivery rate, binds the real reservation into placement `reservationRef`, and rejects placement requests that understate queue-declared demand.
- Added `QueueWLUActivationService`, requiring an ACTIVE reservation and matching placement lease before the shared record may transition `waiting -> running` under the normal per-QID lock.
- Added `QueueWLUUsageService`; consumption is fenced by the QID lock and requires authoritative `running` state.
- Added durable `queuerexx.wlu_lifecycle.v1` evidence and class-owned WLU lifecycle/terminal/action/status constants.
- Refactored `QueueTransitionService` with `transitionWithLock()` so composed authorities may persist side intent, commit the queue state transition, and settle/release WLU while retaining the same QID lock. Existing `transition()` callers remain unchanged.
- Added WLU terminal objects: complete/fail settle actual WLU; cancel releases unused work while preserving consumed work and releases WLU/s capacity.
- Hardened WLU lock ownership against propagated ooRexx conditions: reservation, release, activation, usage, terminal and recovery paths release their QID lock before propagating; injected consume/settle failures are regression-tested.
- Added idempotent WLU lifecycle recovery for queue-commit/WLU-close crash windows. Ambiguous queue evidence fails closed.
- Added cross-engine accounting recovery: if QueueBash itself commits `done`/`failed`/`cancelled`, QueueRexx respects that terminal queue authority and completes only missing WLU settlement/release.
- Added a real QueueBash 0.18.144 `queue cancel --force` qualification proving cancelled queue state is retained while WLU consumed work is preserved and unused WLU/WLU-s reservations are released by QueueRexx recovery.
- Added `QueueJobStatusProjection` / `QueueJobStatusProjector`, separating durable Migratable Job state from retained Queue Fabric live status and classifying synchronization/divergence without granting read-model authority. Optional WLU projection is composed into the same read surface.
- Preserved exact QueueBash 0.18.144 compatibility, Migratable Job v0.2.2 retained status subscription, Observation v0.5 bridge, mixed-engine locking/races and Foreign Runtime/OpenSSL SHA-256 preference.
- Public QueueRexx payload launch and public submit/run/cancel/migrate/daemon mutation remain disabled.

## 0.1-dev6 — QueueBash 0.18.144, retained migration status, diagnosis and lock hardening

- Rebased exact shared-filesystem compatibility onto supplied QueueBash 0.18.144, including root-created lock-tree and reconciliation-archive ownership repair.
- Added detailed QID lock acquisition results so permission failure is reported as `LOCK_PERMISSION_DENIED` rather than masquerading as contention/timeout.
- Enriched QueueRexx lock metadata with uid/user/host/actor/queue-root and Linux process-start cookie; same-host PID reuse is detected, while foreign-host locks remain conservative.
- Added bounded non-mutating `queuerexx diagnose QID --json` with `queuerexx.diagnosis.v1` classification.
- Updated exact migration binding to Migratable Job v0.2.2 and added retained `migratable.job.status/1` subscriber queues with monotonic sequence filtering.
- Preserved typed submission/admission and Foreign Runtime/OpenSSL SHA-256 preference.

## 0.1-dev5 — typed operations, Migratable Job v0.2.1, Foreign Runtime SHA-256

- Added first typed submit/worker-admission layer above the recovery-safe mutation kernel.
- Added Foreign Runtime/OpenSSL SHA-256 provider-evidence qualification and mixed QueueBash execution compatibility.

## 0.1-dev4 — exact Migratable Job authority integration

- Bound QueueRexx directly to the supplied Migratable Job API and normal QID lock/transition authority without a parallel migration state machine.

## 0.1-dev3 — recovery-safe shared mutation kernel

- Added class-owned mutation vocabulary, QueueBash-compatible locks, exclusive allocation, atomic transitions, immutable recovery phases and idempotent event completion.

## 0.1-dev2 — typed health and observation parity

- Added numeric QueueState constants, direct/systemd observations, launch-window/unknown deferral, bounded health and Observation v0.5 bridge.

## 0.1-dev1 — read-only compatibility foundation

- Added native non-evaluating QueueBash reader, exact list JSON parity, provider contracts and mandatory ooRexx structured-data classes.
