# ooRexx Migratable Job v0.2.5

`migratable.job/0.2` coordinates deliberate migration of a pausable,
checkpointable job from one Job-to-Node placement owner to another while
preserving checkpoint, placement, execution and provenance evidence.

The ordinary direct path is:

`NEW -> PREPARING -> READY -> TRANSFERRING -> COMMITTING -> RUNNING`

A transported handoff uses:

`... -> COMMITTING -> AWAITING_DESTINATION -> RUNNING`

`PAUSED` is recoverable and carries an explicit resume state. `FAILED` is used
for integrity/binding failures.

## Safety boundary

Planned migration is not Job-to-Node node-loss recovery.  The source runtime is
first stopped at a migration-safe point and checkpointed.  Only then is its
ownership epoch fenced.  Source admission is released as a separate authority
transition and a destination lease can only be allocated afterwards.

v0.2 journals the ownership fence **before** attempting admission release, and
journals admission release **before** placement.  If the process dies after an
allocator authority change but before the journal append, restart reconciliation
uses Job-to-Node's restored current lease, ownership epoch and admission state as
the authority of record.

There is no intended interval in which source and destination are both current
executable owners.


## Remote initial start (v0.2.5)

v0.2.5 adds `migratable.job.remote-start/1`. A managed `NEW` placement can now
be started on the allocated remote node through Queue Fabric without giving the
transport placement authority. `MigratableJobQueuePlacedStartExecutor` sends a
primitive request/reply message; `MigratableJobRemoteStartService` revalidates
the exact Job-to-Node lease immediately before entering `migratable.job.start/1`.

Destination verification can use either a resident allocator or the exact
network allocator API `job.node.allocator.network/0.1`. Remote RPC replay and
standard starter replay are separate durable layers. If dispatch succeeds but
the reply is uncertain, managed placement reports
`START_PENDING_PLACEMENT_HELD` rather than releasing a possibly-running job.
See `docs/REMOTE_START.md`.

v0.2.5 also corrects internal epoch-millisecond generation by raising ooRexx
`NUMERIC DIGITS` before `TIME('T') * 1000`; qualification exposed that default
precision can collapse adjacent millisecond values at current Unix epochs.

## Managed initial placement (v0.2.4)

v0.2.4 adds `migratable.job.placement/1`, a standard managed surface over
Job-to-Node for initial `NEW` execution.  It provides read-only `PLAN`,
authoritative `ALLOCATE`, lease `CHECK`, placement-bound `START`, conservative
`ALLOCATE_START`, and explicit `RELEASE`.  `START` cannot enter the standard
starter until `JobNodeAllocator~verifyLease()` accepts the exact lease/request.

Planning is advisory only; admission and ownership remain exclusively
Job-to-Node authority.  Failed or ambiguous starts retain the placement rather
than automatically releasing it.  A digest-protected placement audit log links
operation IDs, placement IDs/ownership epochs, starter IDs and execution refs.
See `docs/MANAGED_PLACEMENT.md`.

## Standard starter: `migratable.job.start/1`

v0.2.3 standardises how a migratable workload enters the framework.
`MigratableJobStarter` provides the same durable request/binding path for an
initial `NEW` start, coordinator `RECOVER`, and committed destination `HANDOFF`.
A digest-protected start receipt is claimed before runtime side effects; a
completed `RUNNING` receipt stores the stable execution reference. Replaying the
same successful `startId` therefore returns the existing execution instead of
starting another one, while reusing a start id with a different binding fails
closed.

`MigratableJobStartLayout` standardises the durable subtree containing the
migration journal, provenance ledger, start receipts and handoff directory. Job
and partition ids are hex-encoded in paths. `MigratableJobStarterDestinationRunner`
lets the existing Queue Fabric and file/manual receivers route destination starts
through the same starter without changing their acknowledgement protocol.

A workload implements only `MigratableJobStarterApplication~definition()` and an
idempotent `~startNew()`. `startNew()` must use `request~startId` as its runtime
idempotency key because a process can die after the runtime side effect and before
the final RUNNING receipt append.

See `docs/STARTER_CONTRACT.md`.

## Three resume-delivery modes

The data plane and control plane are separate. Storage Fabric moves/verifies the
checkpoint. Resume delivery can then be:

- **Direct** — the coordinator calls `resumeFromCheckpoint()` locally; this is
  the v0.1-compatible default.
- **Queue** — `MigratableJobQueueChannelTransport` sends a persistable primitive
  handoff through Queue Fabric remote queues. A destination worker starts the
  job and sends an acknowledgement back through Queue Fabric.
- **File/manual** — `MigratableJobFileHandoffTransport` emits a digest-protected
  `.mjob` control manifest. The checkpoint can be copied separately, manually
  started on the destination, and a digest-protected acknowledgement carried
  back.

Queue insertion and file creation are not execution proof. The source stays in
`AWAITING_DESTINATION` until a destination acknowledgement matching handoff id,
job, checkpoint, destination placement and ownership epoch is accepted.

See `docs/HANDOFF_TRANSPORTS.md`.

## Live job status: publish/subscribe, not a direct queue

Live job and migration status is observational fan-out. v0.2.2 therefore uses
Queue Fabric topics and **subscriber queues** rather than an addressed direct
status queue. `MigratableJobTopicStatusPublisher` publishes
`migratable.job.status/1` primitive snapshots to a stable per-job/per-migration
subtopic. Every matching subscription receives its own ordinary queue delivery;
a UI, logger, monitor and audit consumer cannot consume one another's copy.

Status snapshots include the migration's monotonic `sequence`. Publications are
retained by default so a late subscriber can receive the current snapshot
immediately. Job-specific subscription patterns are produced by
`MigratableJobStatusTopicAddress~jobPattern(jobId)`; `~allPattern` observes all
jobs. Queue Fabric's distributed-topic layer may advertise the same subscription
interest between queue managers when cross-node status observation is needed.

Status publication occurs only after the coordinator's authority state has been
persisted/reconciled. It is deliberately **non-authoritative**: status fan-out
failure/backpressure is recorded as `STATUS_PUBLICATION_FAILED` provenance but
does not roll back a fence, placement, transfer commit or running execution.
Migration commands and destination acknowledgements remain addressed direct
queue traffic because they are point-to-point control operations.

See `docs/STATUS_SUBSCRIPTIONS.md`.

## Authority boundaries

- **Job-to-Node Allocator v0.6** — hard eligibility, placement, admission/WLU,
  leases, ownership epochs and fencing.
- **Storage Fabric v0.1-dev7** — resumable checkpoint movement and byte/content
  verification.
- **Queue Fabric v0.9-dev5** — queued/store-and-forward delivery. v0.2 uses
  `QueueChannelFabric` primitive payloads so the handoff can cross persistence
  and socket boundaries.
- **Execution runtime** — real safe point, checkpoint, restore/start and source
  retirement.
- **Commit authority** — explicit permission to make the verified destination
  executable.
- **Migratable Job** — ordering, durable transaction state, cross-component
  evidence binding and provenance.

## Destination selection

`MigratableJobDestinationAssessor` is a Job-to-Node hard-constraint assessor.
It excludes the source when required and can restrict migration to a supplied
set of destination node ids. Job-to-Node still selects among eligible nodes by
its normal capability/capacity policy, so a newly available fast CPU/GPU/cloud
node needs no migration-specific scoring logic.

## Checkpoint and provenance

`MigratableJobCheckpointManifest` binds the durable state to job/migration,
partition, source node/placement/ownership epoch, runtime generation, executable
revision, state reference/digest, evidence references and timing/resume
sequence.

`MigratableJobDurableJournal` is append-only and digest protected. STATE2 adds
handoff mode/id/reference and can still read v0.1 STATE records.  When supplied
to the coordinator, snapshots are intrinsic: callers no longer have to remember
to append after state changes.

`MigratableJobProvenanceLedger` remains a separate hash-chained event stream:
the durable journal answers "where can I resume?" while provenance answers
"what authority/evidence transitions happened?".

Restore Job-to-Node durable authority state before restoring a migration.
`MigratableJobCoordinator~restore()` then reconciles the migration snapshot
against allocator authority before further action.

## Source layout

- `src/MigratableJob.cls` — model, policies, provenance, authority handoff,
  reconciliation and coordinator.
- `src/MigratableJobDurable.cls` — durable transaction snapshots.
- `src/MigratableJobStorageAdapter.cls` — Storage Fabric transfer adapter.
- `src/MigratableJobHandoff.cls` — common queue/file instructions,
  acknowledgements, file transport and destination runner.
- `src/MigratableJobQueueFabricAdapter.cls` — legacy placement-envelope helper
  plus the v0.2 QueueChannelFabric inter-node transport/worker/ack reader.
- `src/MigratableJobStatusTopic.cls` — retained QueueTopicFabric live-status
  publisher and subscriber-address helpers.
- `src/MigratableJobRemoteStart.cls` — managed remote NEW-start Queue Fabric RPC,
  durable replay ledger and local/network Job-to-Node lease verifiers.
- `src/MigratableJobStarter.cls` — standard NEW/RECOVER/HANDOFF starter, durable
  start-id receipts, safe state layout and queue/file destination bridge.
- `docs/DESIGN.md`, `docs/HANDOFF_TRANSPORTS.md`, `docs/STATUS_SUBSCRIPTIONS.md`, `docs/STARTER_CONTRACT.md`, `docs/REMOTE_START.md` — authority, transport, observation and standard-start design.
- `tests/` — executable qualification probes.

## v0.2.5 remote placed start

Managed `ALLOCATE_START` can now use `MigratableJobQueuePlacedStartExecutor` to
start an initial `NEW` execution on the node selected by Job-to-Node. The
destination revalidates the lease immediately before entering
`migratable.job.start/1`; verification can use a resident allocator or the
network authority `job.node.allocator.network/0.1` `CHECK` operation. Queue reply
uncertainty is reported as `START_PENDING_PLACEMENT_HELD`, preserving ownership
until the result is reconciled. Durable remote RPC replay is separate from the
standard starter receipt, providing two layers of duplicate suppression without
duplicating placement authority.

## Qualification baseline

Qualified on the user-supplied 13 September 2026 roll-up with ooRexx 5.3.0
r13196 internal/debug build, Job-to-Node v0.6, Storage Fabric v0.1-dev7, Queue
Fabric v0.9-dev5 and Crypto v0.8.3. See `VALIDATION.txt`.

## Crypto acceleration qualification

v0.2.1 corrected the v0.2 qualification harness: the default `JobNodeDigestProvider` already uses Crypto `.SHA256`; when Crypto's `CryptoForeignRuntimeInstaller` is installed, that unchanged public API delegates `crypto.sha256.digest/1` through Runtime Reference to Foreign Runtime and OpenSSL/libcrypto.  The qualification runner now requires Runtime Reference v0.4 and Foreign Runtime v0.22.6, installs the resident Crypto provider in each functional qualification process, and verifies provider evidence explicitly.  Pure ooRexx SHA remains Crypto's fallback, not the expected high-throughput deployment path.
