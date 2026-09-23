# FD Door Micro Motion v0.2-dev8 — Migratable Job integration

Baseline: Migratable Job v0.2.5, main API `migratable.job/0.2`, standard starter `migratable.job.start/1`, managed initial placement `migratable.job.placement/1`, remote initial start `migratable.job.remote-start/1`; Job-to-Node v0.6 remains placement authority.

## NEW execution

The FD workload definition carries the native `JobPlacementRequest`. FD does not create a placement ID or ownership epoch.

For local/reference qualification the existing managed-placement bridge still supports PLAN/ALLOCATE/CHECK/START against a resident authoritative allocator. Fleet deployment instead consumes the QueueRexx-managed network authority and uses Migratable Job v0.2.5's remote placed-start protocol:

```text
Job-to-Node network PLAN / ALLOCATE
 -> native JobNodePlacementLease
 -> authoritative CHECK
 -> MigratableJobQueuePlacedStartExecutor
 -> Queue Fabric direct request
 -> MigratableJobRemoteStartService on destination
 -> authorised route + exact lease re-CHECK
 -> migratable.job.start/1
 -> FDDoorMicroMotionStarterApplication
 -> private FD worker
```

Queue delivery is never execution authority. The destination revalidates the exact lease immediately before the standard starter.

Remote-start RPC replay and starter replay are deliberately separate. The RPC ledger binds `startId` to client + destination + exact lease + exact start request. Exact replay returns the prior response; changed binding under the same `startId` fails `REQUEST_ID_CONFLICT`. The starter's own start receipts remain the runtime-side idempotency authority.

If a request was queued but no reply arrives, v0.2.5 surfaces `REMOTE_START_PENDING` / `START_PENDING_PLACEMENT_HELD`. That is uncertainty, not failure-to-start. Placement must remain held until the same request is retried/collected or runtime absence is proved independently.


## Source stability across NEW and resume

The strong `source_evidence_ref` remains the portable content identity across nodes.  On each execution host, dev8 additionally constructs an ooRexx POSIX coherent source guard before FFmpeg opens the file.  The guard observes coherent `stat` + `lstat` identity, size, mtime/ctime and raw symlink target across a quiet interval, checks again after decoder open, then periodically and at checkpoint/finalisation boundaries.

A changing source fails closed as `SOURCE_NOT_STABLE_AT_START`, `SOURCE_MUTATED`, or `SOURCE_STAT_FAILED`.  A preflight failure is written to `state/source.guard.failure.tsv`; it deliberately does **not** overwrite an existing merged scientific `.run.tsv`, which matters when a destination RESUME discovers that its local source copy is not yet stable.

The POSIX device/inode tuple is local provenance only and is never treated as cross-node identity or migration authority.

## Video checkpoint state

Pause is honoured only after one decoded frame and all evidence rows from that frame are committed. The checkpoint binds source/evidence identity, analyser revision/config, frame/PTS state, F11 fingerprint, geometry epoch, relocation/exclusion state, noise model, event accumulator, checkpoint generation, and the complete dev7 temporal door model:

- slow gap baseline;
- filtered gap;
- sustained-direction/count;
- last deflection;
- observation/baseline-update counts.

This prevents a migration from silently resetting the slow visual baseline and changing scientific interpretation.

The transfer object remains a digest-bound uncompressed `.fdmjob.tar` containing checkpoint plus committed evidence shards.

## Planned migration

Remote-start is for initial NEW execution only. Planned migration destination handoff remains:

```text
pause/checkpoint
 -> source ownership fence
 -> destination Job-to-Node allocation
 -> Storage Fabric transfer/verification
 -> explicit commit
 -> migratable.job.start/1 HANDOFF
 -> destination-running acknowledgement
 -> source retirement/provenance
```

The committed destination node/placement/ownership epoch is consumed unchanged. FD never reruns NEW placement during HANDOFF.

Decoder internals are not serialized. Resume reopens the strongly identified source, seeks before committed PTS, replays while suppressing evidence through committed PTS, and emits from the first uncommitted frame.
