# QueueRexx v0.1-dev12

QueueRexx is an ooRexx-native implementation of the QueueBash queue fabric. It is not a new queue format and it is not a wrapper around QueueBash.

**Compatibility baseline:** QueueBash 0.18.144 BOB27 lock-tree ownership hotfix.

**Migration baseline:** Migratable Job v0.2.4 / API `migratable.job/0.2`, including starter contract `migratable.job.start/1` and managed placement contract `migratable.job.placement/1`.

**WLU baseline:** Work Load Units v0.12 / API `work.load.units/0.12`, composed with Job-to-Node Allocator v0.6.

The shared `.queuebash` filesystem remains authoritative. QueueBash and QueueRexx may inspect and operate on the same job records; QueueRexx adds an OO/provider/recovery architecture without silently creating a second queue format.

The public QueueRexx CLI remains inspection-only in dev12. Typed submit/admission, WLU lifecycle, scheduling, payload execution, migration starter guarding and recovery objects are qualified internal/API surfaces; public `submit`, `run`, `cancel`, `migrate`, and `daemon` commands remain disabled.

## What dev11 adds

1. **Exact QueueBash execution-policy provider.** `QueueBashClassPolicyProvider` invokes the supplied QueueBash 0.18.144 worker execution policy gate instead of translating its class-policy/authorisation rules into a second implementation.
2. **Non-mutating policy inspection.** The provider evaluates a temporary copy of the `.job` record, preserving QueueBash policy semantics while preventing a read-only check from appending exemption metadata to authoritative queue state.
3. **Read-only `policy-check`.** `queuerexx policy-check QID --json` exposes typed allow/deny/error evidence as `queuerexx.policy_assessment.v1`.
4. **Internal worker policy binding.** `QueueBashExecutionPolicyGate` plugs the provider into typed worker admission. A deny is converted to `running -> pol_blocked` only by the existing `QueueTransitionService`.
5. **Command-bound authorisation parity.** QueueBash-created on-file authorisations are validated by QueueBash itself and honoured by QueueRexx; QueueRexx does not mint or reinterpret those credentials.
6. **Fail-closed compatibility checks.** Missing QueueBash source, wrong QueueBash version, duplicate QID authority and non-running worker-policy use are denied/error outcomes rather than implicit allow.
7. **Authoritative Job-to-Node lease verification.** WLU scheduling no longer treats a matching `reservationRef` as sufficient placement evidence. QueueRexx retains the exact `JobPlacementRequest` and asks Job-to-Node v0.6 `verifyLease()` to validate the current ownership fence, admission reservation, lease/capacity freshness, capability and observation generations, request/capability/capacity digests and allocator policy generation.
8. **Fail-closed placement evidence.** Missing placement authority, a missing exact placement request, stale/superseded lease evidence, lost admission recovery state or verification conditions make the job ineligible; QueueRexx does not reconstruct a placement verdict from copied lease fields.
9. **Migratable Job v0.2.4 managed placement.** Migratable NEW execution uses upstream `migratable.job.placement/1` for PLAN/CHECK/ALLOCATE/START/ALLOCATE_START/RELEASE instead of inventing a QueueRexx placement state machine. `QueueRexxManagedPlacementFacade` durably records only the exact NEW-start intent before authoritative allocation.
10. **Launch-boundary revalidation.** `QueueRexxPlacedStartExecutor` reacquires the shared QID lock, rechecks queue/policy authority and asks Job-to-Node v0.6 to verify the exact current lease immediately before entering `migratable.job.start/1`. A lease that becomes stale after the outer managed-placement check is rejected before runtime entry and remains held for explicit release.
11. **Restart-safe placement replay.** After QueueRexx restart, the durable NEW-start intent reconstructs the same framework request; v0.2.4 answers the same verified allocation as `PLACED_REPLAY` without QueueRexx persisting a shadow placement lease or raw allocator authority.
12. **Durable Job-to-Node frontage.** Optional `QueueRexxJobNodeDurable.cls` wraps the exact v0.6 `JobNodeDurablePlacementManager`. Restore is mandatory before mutation; allocator sequence, ownership epoch, placement lease and WLU-backed admission proof survive reconstruction while Job-to-Node remains the only placement authority.
13. **Dev10 guarantees retained.** Provider telemetry, Observation v0.5 projection, durable trigger replay, bounded fleet recovery, QueueBash-to-WLU staging, Migratable Job v0.2.3 starter guarding, runtime recovery and Foreign Runtime SHA acceleration remain unchanged as historical dev10 behavior.

QueueRexx is still not a shell rewrite or a general wrapper around QueueBash. The dev11 policy adapter is intentionally narrow: QueueBash remains the policy compatibility oracle for its existing worker execution semantics, while QueueRexx retains its own OO queue, recovery, WLU, placement, migration and provider model.

See `docs/PROVIDER_CONTRACTS.md`, `docs/TYPED_OPERATIONS.md`, `docs/RUNTIME_RECOVERY.md`, `docs/MIGRATABLE_JOB_INTEGRATION.md` and `docs/WLU_INTEGRATION.md`.

### Dev12 authority-server and peer-mesh increment

Dev12 makes QueueRexx a real Job-to-Node authority server inside the general QueueRexx peer mesh. QueueRexx owns authority lifecycle and recovery for the exact JobNodeAllocator v0.6 authority, its durable allocator journal, WLU-backed admission restoration, the exact `job_node_allocator_v0.6-network1` service/ledger/access-policy stack, client ACL/reply bindings, and Queue Fabric v0.9-dev5 `queue.transport/2` connectivity. FD and Migratable Job consume the exact upstream `JobNodeNetworkAllocatorClient` operations `PLAN / ALLOCATE / CHECK / RENEW / RELEASE`; they do not maintain a fallback allocator. Migratable Job v0.2.4 then retains managed placement, exact lease verification and `migratable.job.start/1`.

The authority server restores Job-to-Node durable state before network mutation, drains durable requests accepted before a crash before waiting for new transport, replays exact responses by stable `requestId`, rejects changed-content reuse, and leaves replies durably queued when a client is temporarily offline. General peer connectivity/trust is reconstructed from `queuerexx.peer.mesh.config/1`; Job-to-Node service authorization is a separate semantic binding from client to peer, allowed network1 operations, optional owner and server-owned reply queue. See `docs/AUTHORITY_SERVER.md`.

Dev12 also contains the general `queuerexx.peer.mesh/0.1` QueueRexx node fabric for inter-node approvals, checks and service routing. `QueueRexxPeerMeshRuntime~bindServiceRoute()` lets multiple logical services reuse one authenticated peer relationship; Job-to-Node network1 is the first authority service carried this way. The mesh itself is not placement authority and cannot mint or validate Job-to-Node leases. See `docs/PEER_MESH.md`.


## Execution and scheduling model

```text
QueueJobScheduler
    eligibility: policy / WLU reservation / placement
    ordering:    normal queue priority
          |
          v
QueueTypedWorker
    claim or WLU activation under QID authority
          |
          v
QueueExecutionService
    PREPARED execution journal
    -> selected RunnerProvider.prepare/launch
    -> durable provider PID/exit or systemd unit locator
    -> atomic runtime metadata
    -> observe/reconcile
    -> done | failed | cancelled only from authoritative evidence
```

The direct backend uses a non-capturing launcher path for deliberately backgrounded payloads; launch identity is returned through the durable PID locator instead of keeping ooRexx `ADDRESS SYSTEM WITH OUTPUT` pipes attached to a background process.

## Authority model

```text
.queuebash filesystem
    QID + queue lifecycle authority
          |
          +---- WLU Authority
          |       work entitlement / throughput / consumption / settlement
          |
          +---- Job-to-Node Allocator
          |       placement + admission + reservationRef + ownership fencing
          |       current-lease verification against retained placement intent
          |             |
          |             +---- Migratable Job
          |                    start receipts + planned execution-ownership handoff
          |
          +---- runner/process providers
                  execution mechanism + liveness evidence
```

These authorities are composed, not collapsed. A retained status topic, telemetry stream or monitoring projection never authorizes a state transition, migration commit, WLU settlement, start replay, or ownership change.

## WLU model

A managed request may declare 2.0 expected WLU, a 3.0 WLU ceiling, a 4 second target and 0.5 WLU/s. QueueRexx stores integer micro-WLU, reserves the full ceiling and requested rate at WLU Authority, then binds that reservation into the Job-to-Node placement lease. Acceleration changes delivery capacity; it does not manufacture extra work units.

QueueBash-created jobs may be staged through `QueueRexxWLUBridge`; this is an admission bridge, not a second queue representation.

## Migration/status model

Migratable Job v0.2.4 remains migration/start authority. The main API remains `migratable.job/0.2`; standard start entry remains `migratable.job.start/1`, and v0.2.4 adds managed initial-placement API `migratable.job.placement/1` plus audit receipt API `migratable.job.placement.receipt/1`.

For ordinary direct starter use, `QueueRexxMigratableStarterApplication` retains the dev10 NEW guard. For managed NEW execution, QueueRexx instead wraps the upstream `MigratableJobManagedPlacementTool` with a durable start-intent facade and supplies `QueueRexxPlacedStartExecutor`. Migratable Job/Job-to-Node own allocation, lease verification, placement replay and release; QueueRexx owns only the shared QID/policy guard and a second Job-to-Node lease verification under that QID lock immediately before starter entry. RECOVER and HANDOFF remain framework-owned paths.

The same QueueBash QID record remains `running` throughout planned migration. QueueRexx subscribes to the retained `migratable.job.status/1` topic through its own ordinary Queue Fabric queue, rejecting stale/redelivered snapshots by migration-local sequence. `QueueJobStatusProjector` keeps durable authority and retained live status visibly separate.

## SHA-256 acceleration

QueueRexx callers use the ordinary Crypto `.SHA256` API. For throughput-sensitive use, QueueRexx lazily prefers the supplied Crypto Foreign Runtime/OpenSSL provider; qualification requires Runtime Reference evidence `providerId=foreign.openssl.crypto` and `outcomeCode=COMPLETED`. Pure ooRexx SHA-256 remains fallback.

## Class-owned constant rule

Fixed domain values belong to their owning class. QueueBash/API spellings are converted only at persistence/render boundaries; behavior is selected by object/provider dispatch rather than provider-name string branching.

## Structured-data rule

- JSON: stock ooRexx `json.cls` / `.JSON` only.
- CSV and TSV: stock ooRexx `csvStream.cls` / `.CSVStream` only; TSV uses TAB (`'09'x`).
- YAML: stock ooRexx `yaml.cls` / `.Yaml` only.

## Commands

The ordinary CLI remains inspection-only:

```text
queuerexx version [--json]
queuerexx list [--state STATE] [--json]
queuerexx explain QID [--json]
queuerexx providers [--json]
queuerexx provider-plan QID [--json]
queuerexx provider-health [--json]
queuerexx policy-check QID [--json]
queuerexx observe QID [--json]
queuerexx health [--deep] [--json]
queuerexx diagnose QID [--json]
queuerexx runtime-status QID [--json]
queuerexx runtime-scan [--json]
```

There is no public `submit`, `run`, `daemon`, `sentinel`, `cancel`, `migrate`, starter, trigger-fire, fleet-recovery, or runtime-recovery command yet.

## Tests

Run the suite with:

```bash
tests/run.sh
```

Optional exact integrations are enabled through the environment variables documented in `VALIDATION.md`. The release is qualified with the user-supplied Open Object Rexx 5.3.0 r13196 debug build.

### Deliberate dev11 boundary

QueueBash worker admission performs class/resource availability checks before execution-policy evaluation. Dev11 binds the execution-policy authority only and does **not** claim full QueueBash worker-admission parity. Class/preflight parity remains a separate provider boundary for the next increment.

Dev11 also closes the previous placement-token shortcut for WLU scheduling: a copied `reservationRef` is not placement authority. The current lease must be accepted by Job-to-Node v0.6 against the exact placement request and current allocator evidence. `QueueDurableJobNodeAllocator` now preserves Job-to-Node sequence/ownership/admission state across restart, including WLU-backed reservation proof recovery. `QueueMemoryPlacementLeaseLookup` remains only an in-process request/lease discovery helper for the generic non-migratable scheduler, so a public remote/fleet scheduler still needs a durable way to rediscover its exact request+lease and must revalidate at the final launch boundary. Migratable NEW execution already has those boundaries through the durable NEW intent, v0.2.4 managed placement and `QueueRexxPlacedStartExecutor`.
