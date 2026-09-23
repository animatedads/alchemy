# Standard Migratable Job starter — `migratable.job.start/1`

Migratable Job v0.2.3 standardises process entry as well as migration.
Workloads should not create independent shell conventions for initial launch,
coordinator recovery and destination handoff.

## Start modes

`MigratableJobStarter` accepts a `MigratableJobStartRequest` in exactly one of
three modes:

- `NEW` — first execution of a workload. The workload's
  `MigratableJobStarterApplication~startNew()` performs the local runtime start.
- `RECOVER` — reopen the durable migration transaction, reconcile allocator
  authority through the coordinator, and advance or resume it.
- `HANDOFF` — consume a committed `MigratableJobHandoffInstruction` on a
  destination and start it through the common `MigratableJobDestinationRunner`.

The start API is `migratable.job.start/1`. The durable receipt contract is
`migratable.job.start.receipt/1`.

## Stable request binding

A request binds:

- `startId`;
- mode;
- `jobId` and `definitionRef`;
- partition id;
- optional migration id;
- optional committed handoff instruction;
- optional destination checkpoint override;
- lease duration / bounded transfer work for recovery;
- optional metadata reference.

`requestedEpochMs` is deliberately not part of the idempotency fingerprint: a
retry at a later time is still the same logical start.

For `HANDOFF`, an empty `startId` adopts the handoff id. This makes the existing
migration handoff id the natural destination-start idempotency key.

## Idempotency and crash window

Before a runtime side effect, `MigratableJobStartReceiptStore` appends a
digest-protected `CLAIMED` receipt. A completed start appends `RUNNING` with its
stable execution reference.

Repeating the same successful request returns the durable execution reference
without invoking the runtime again. Reusing a `startId` with a different
request fingerprint fails closed as `START_ID_CONFLICT`.

A crash can occur after the runtime has started but before `RUNNING` is appended.
Therefore a `NEW` workload executor **must** treat `request~startId` as its
idempotency key. Replaying that start id must return the same logical execution,
not create another execution. Destination handoff already has the corresponding
handoff-id idempotency requirement.

`FAILED` and `PENDING` receipts are not sticky terminal suppression states: the
same correctly-bound `startId` may retry. `RUNNING` is replayed without a new
runtime call.

Receipt integrity is fail-closed. A corrupt receipt stream blocks execution
rather than silently discarding duplicate-suppression evidence.

## Standard durable layout

`MigratableJobStartLayout` creates one predictable state subtree:

```
<root>/
  job-<hex(jobId)>/
    partition-<hex(partitionId)>/     # when a partition is supplied
      migration.journal
      provenance.events
      start.receipts
      handoff/
```

Job and partition identifiers are hex encoded so identifiers cannot traverse out
of the configured state root.

The layout is a naming convention, not a new authority. The migration journal,
provenance ledger, Job-to-Node authority and Storage/Queue Fabric contracts keep
their existing semantics.

## Workload seam

A workload implements `MigratableJobStarterApplication`:

- `definition(request)` returns the stable `MigratableJobDefinition`;
- `startNew(request, definition)` performs an idempotent first local start and
  returns `MigratableJobResumeResult`;
- optional `afterStart(request, result)` observes the final starter result.

The starter validates job, definition and partition binding before executing.
It does not let a workload change allocator, storage, queue or commit authority.

## Queue and file handoff integration

Queue Fabric and manual/file receivers should not invoke the local destination
runner directly. Wrap the standard starter with
`MigratableJobStarterDestinationRunner` and give that bridge to the existing
queue/file destination consumer.

Conceptually:

```
Queue/File handoff
    -> MigratableJobStarterDestinationRunner
    -> MigratableJobStarter (HANDOFF)
    -> durable start-id claim/replay check
    -> MigratableJobDestinationRunner
    -> workload destination executor
    -> destination acknowledgement
```

This preserves the existing acknowledgement wire contract while ensuring that
all transports get the same duplicate suppression and definition binding.

## Recovery result

`RECOVER` returns:

- `RUNNING` when the restored transaction is or becomes running;
- `RECOVERY_PENDING` when a valid migration remains paused/in progress or awaits
  destination acknowledgement;
- failure when the durable snapshot, definition binding or migration itself is
  invalid/failed.

The starter does not manufacture an acknowledgement and does not treat queue
insertion as running state.

## Authority boundary

The starter is orchestration and idempotency infrastructure only:

- Job-to-Node remains placement/lease/ownership/admission authority;
- Storage Fabric remains checkpoint transfer/verification authority;
- Queue Fabric remains transport authority;
- commit authority remains explicit;
- runtime adapters remain execution authority;
- `MigratableJobStarter` standardises entry, binding, durable start receipts and
  dispatch into those existing authorities.
