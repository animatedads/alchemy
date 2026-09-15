# FD Door Micro Motion v0.2-dev5 — Migratable Job integration

Baseline: Migratable Job v0.2.4, main API `migratable.job/0.2`, standard starter `migratable.job.start/1`, managed initial placement `migratable.job.placement/1`, placement audit `migratable.job.placement.receipt/1`; Job-to-Node v0.6.

## NEW ownership

The workload definition carries the native `JobPlacementRequest`. FD does not accept an operator-created placement ID/epoch as NEW authority.

```text
PLAN       read-only eligibility/ranking
ALLOCATE   JobNodeAllocator authority transition
CHECK      JobNodeAllocator.verifyLease(exact request)
START      verified lease -> standard starter
```

`FDDoorMicroMotionPlacedStartExecutor` is only the v0.2.4 placed-start seam. It checks that the committed lease belongs to the local assigned node, injects that already-verified lease into the FD application, and enters `MigratableJobStarter`. It never chooses a node or invents a lease.

The Job-to-Node durable journal remains the authority state. `MigratableJobPlacementAuditStore` is append-only evidence, not authority.

A failed or ambiguous start returns `START_FAILED_PLACEMENT_HELD`. Explicit `RELEASE` is the only cleanup path after runtime state is known.

## Safe point/checkpoint

Pause is honoured only after one decoded frame and all evidence rows from that frame are committed. The checkpoint binds source/evidence identity, analyser revision/config, frame/PTS state, F11 fingerprint, geometry epoch, relocation/exclusion state, noise model, event accumulator and checkpoint generation. The transfer object is a digest-bound uncompressed `.fdmjob.tar` containing checkpoint plus committed evidence shards.

## Planned migration

Managed placement is for NEW only. RECOVER/HANDOFF retain their existing Migratable Job authority paths:

```text
pause/checkpoint
 -> coordinator source fence
 -> coordinator destination Job-to-Node allocation
 -> Storage Fabric transfer/verification
 -> explicit commit
 -> migratable.job.start/1 HANDOFF
 -> destination-running acknowledgement
 -> source retirement/provenance
```

The committed destination node/placement/ownership epoch in a HANDOFF is consumed unchanged. FD does not run initial managed placement during HANDOFF.

Decoder internals are not serialized. Resume reopens the strongly identified source, seeks before committed PTS, replays while suppressing evidence through committed PTS, and emits from the first uncommitted frame.
