# Native continuation authority boundary — v0.1-dev7

## Estate sources actually checked

- `job_node_allocator_v0.6-network5.zip` — `JobNodeAllocator~verifyLease`, native `JobNodePlacementLease`, `JobNodeExecutionLifecycleRegistry~stateFor`. `network5` adds runtime-observation reconciliation; the two direct upstream tests below still fail on supplied ooRexx.
- `oorexx_memory_fabric_v0.1-dev10.zip` — the existing `RegisteredJobExecutionContextPlan` / capacity-plan semantics; no Memory Fabric-specific commissioning assumed.
- `migratable_job_v0.2.2.zip` (nested in Audio V9 candidate21) — authoritative migration transaction state machine and distinct checkpoint, transfer, commit, handoff and acknowledgement layers.
- `oorexx_generalized_compute_intentions_v0.1-dev3` remains in the native source eligibility tests.

## Read-only lifecycle

`CloudMigrationContinuationBridge~assessPreflight(estateHandoff,running,offers,routes,definition,sourceRequest,destinationPolicy)`

Requires an *existing* `CloudMigrationEstateHandoff` with `NATIVE_ELIGIBLE_ADVISORY` (not `COMMISSION`); exact native `MigratableJobDefinition` bound to native source `JobPlacementRequest`, same job and runtime as source and destination; configured executable revision/runtime generation; hard `MigratableJobDestinationPolicy` check on the selected physical node; and (if present) the definition's destination-node allowlist. It returns `PREFLIGHT_ADVISORY` with original estate evidence plus a **modelled**, not verified, number of GiB to transfer.

`CloudMigrationContinuationBridge~assessTransfer(preflight,migration,checkpointResult,transferResult,nowEpochMs)`

Read-only reconciliation after the source has been paused by the *separate* Migratable Job coordinator. Requires native record classes; exact definition/source lease identity; bound and time-consistent checkpoint manifest with matching job, migration, partition, runtime, executable generation, source node, placement and ownership epoch; matching transfer reference; source fence and admission-release evidence in the migration record; replacement destination lease record for the same job, node and newer ownership epoch; state `COMMITTING`, `AWAITING_DESTINATION` or `RUNNING`; and a completed transfer whose refs match migration records. Returns `TRANSFER_RECORD_ADVISORY` with modelled transfer price variance, not a settlement.

The two operations must **not** be conflated: a real paused/fenced source will not satisfy dev6's RUNNING check again. The preflight is a snapshot and must not be reused as perpetual authority. The native migration coordinator must revalidate ownership and make actual decisions.

## Hard non-authorities

This bridge **never** calls `MigratableJobCoordinator~begin/step/acknowledge`, `pauseAndCheckpoint`, `retireSource`, `JobNodeAllocator~allocate/renew/release`, a transfer adapter, a handoff transport, `ConnectSelector`, any cloud provisioning API or any posting function. Both result objects return `purchaseAllowed=.false`, `migrationAllowed=.false`, `dispatchable=.false`.

Native record compatibility is **not cryptographic provenance**. Checkpoint `stateDigest` and `verificationRef` strings may be carried by an object without independent re-hashing the Storage Fabric bytes. A constructed destination lease can have the correct class while not being a current allocator-issued lease; only its issuing allocator's `verifyLease` and ownership registry can establish current authority. This module reports a matching *record*, not a verified transfer or authorized resume.

`MigratableJobTransferResult~init` currently calculates `bytesTransferred=bytesArg+0` with default ooRexx numeric digits; a value such as 1,073,741,824 can round. Therefore transfer-cost variance from this class is approximate even with exact input to the constructor. No invoice is posted based on it. Future authoritative accounting needs exact byte counters, provider invoices, actual transport metrics and appropriate decimal precision.

## Upstream findings (not fixed here)

Under ooRexx 5.3.0 r13196:

- JNA network5 `tests/test_execution_lifecycle.rex`: `JobNodeExecutionLifecycleRegistry~observe` yields the literal `RESULT`, not a result object; `x~accepted` raises error 97.1.
- JNA network5 `tests/test_runtime_reconciliation.rex`: Rexx syntax error 35.1 at `call registry~beginPlacement lease`.

Cloud Economics exercises the read-only `stateFor` API using restored native state and passes. Do not interpret that as upstream network5 runtime-observation acceptance.

## Acceptance

`tests/run.sh` automatically includes `tests/test_migration_continuation.rex` when the four prior native-root environment variables and `MIGRATABLE_JOB_ROOT` are supplied. It runs with real ooRexx classes and uses synthetic economic fixtures and synthetic record objects. It exercises hard destination policy, executable/runtime identity, the `COMMISSION` hold, ref conflict, incomplete transfer, checkpoint source mismatch, changed checkpoint identity and transfer cost variance. It does not invoke migration effects or mutate paper accounts.

Expected remaining work: native instrumentation events and dispatch-linked observation for real Migratable Job, transport/Storage Fabric bytes verified by their respective authorities, provider capacity and permission, economic reservation/approval, and accountant-grade invoice reconciliation.
