# Migratable Job v0.2 design

## Core invariant

A planned migration must never intentionally create two current executable
owners.  The source runtime reaches a durable safe point before its Job-to-Node
ownership epoch is fenced.  A replacement lease is allocated only after that
fence and source admission release.

The fence is an authority operation, not a process-stop mechanism.

## State machine

`NEW` creates the transaction. `PREPARING` pauses/checkpoints, fences ownership,
releases admission and obtains replacement placement. `READY` confirms the
lease. `TRANSFERRING` moves/verifies state. `COMMITTING` re-verifies placement
and records explicit commit authority.

With direct control, `COMMITTING` resumes and becomes `RUNNING`. With queue/file
control it creates a stable handoff id, submits the instruction and becomes
`AWAITING_DESTINATION`. Only a matching successful destination acknowledgement
becomes `RUNNING`.

`PAUSED` always includes an explicit resume state. `FAILED` is fail-closed.

## Intrinsic durability and crash windows

v0.1 exposed a journal but left snapshot timing to callers. v0.2 moves that
responsibility into `MigratableJobCoordinator` when a durable journal is
configured.

External authority operations are intentionally separated:

1. checkpoint durable -> journal;
2. Job-to-Node ownership fence -> journal;
3. source admission release -> journal;
4. destination placement -> journal;
5. verified transfer evidence -> journal;
6. commit evidence -> journal;
7. stable handoff id before delivery -> journal;
8. handoff submitted / direct execution -> journal;
9. destination acknowledgement -> journal.

No ordinary filesystem journal can atomically commit with a separate allocator
authority. Therefore recovery also reconciles. After Job-to-Node state is
restored, `MigratableJobPlacementHandoff~reconcile()` can infer:

- a missing source-fenced bit from an advanced ownership epoch;
- a missing source-admission-released bit from allocator admission state;
- a replacement destination lease that became current after the fence but
  before the migration journal append.

A journal claiming the source is fenced while Job-to-Node still reports that
same source placement/epoch as current is an authority regression and fails
closed.

## Destination lease reset

Destination identity is leased authority, not permanent migration identity. A
lease is re-verified before transfer and commit. If it ceases to verify,
destination-specific transfer/commit evidence is discarded, the durable source
checkpoint is retained and the migration returns to PREPARING for a fresh
placement.

## Resume delivery

Checkpoint bytes and resume instructions are distinct.

Queue mode serializes only primitive QueueGraph-compatible values and uses
QueueChannelFabric remote queues. This avoids assuming that arbitrary local
Rexx objects survive persistence/socket transmission. At-least-once delivery is
handled by a stable handoff id; destination execution must be idempotent for
that id.

File mode writes a digest-protected `.mjob` control manifest. Large checkpoint
bytes remain a Storage Fabric/provider object or a separately copied file.
Manual start can override the local checkpoint path; `sha256:` transfer evidence
is checked against that local file before execution.

The acknowledgement is as important as the instruction. Delivery alone never
moves the transaction to RUNNING.

## Execution commit and cleanup

Direct `resumeFromCheckpoint()` or a successful remote destination start is the
execution commit point. Source retirement follows it as cleanup. Cleanup failure
is recorded but cannot demote or replay an already-running destination because
the source was paused and ownership-fenced before destination placement.

## Forensic workloads

A workload's checkpoint should keep deterministic continuation state behind
`stateRef`: partition identity, exact input hashes, algorithm/config revision,
partial-output ledger, model state and any random/temporal state needed for
reproducibility. Node history, placement/ownership epochs and execution timing
remain migration provenance.

The opaque state reference is compatible with Storage Fabric,
JournalPointedState exports, database checkpoints or application-specific state.

## Standard start boundary (v0.2.3)

Process entry is now a first-class framework boundary. `migratable.job.start/1`
normalises `NEW`, `RECOVER` and committed destination `HANDOFF` through one
binding/idempotency path. This does not turn Migratable Job into a scheduler:
Job-to-Node remains placement/ownership authority and a workload's NEW executor
must run only in its authorised placement context. The starter's authority is
limited to request binding, durable start-id receipts, durable-path convention
and dispatch into the existing coordinator/destination runtime seams.

A stable `startId` is mandatory. The receipt store writes `CLAIMED` before a
runtime side effect and records `RUNNING` with the execution reference after a
successful start. Because a crash may occur between those writes, the local NEW
runtime adapter must make the start operation idempotent by `startId`. Queue and
file destination starts use the migration handoff id as that key through
`MigratableJobStarterDestinationRunner`.
