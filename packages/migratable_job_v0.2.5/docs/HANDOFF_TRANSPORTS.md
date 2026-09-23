# Handoff transports

Migratable Job deliberately separates **migration authority**, **checkpoint data
movement**, and **resume-instruction delivery**.

The invariant is the same for every transport:

1. pause at a workload-defined safe point and make the checkpoint durable;
2. fence the source Job-to-Node ownership epoch;
3. release source admission;
4. obtain a new destination placement;
5. transfer and verify checkpoint bytes;
6. obtain explicit migration commit authority;
7. deliver a resume instruction;
8. destination verifies/starts and returns an acknowledgement;
9. only the acknowledgement moves the source transaction to `RUNNING`.

A successful queue `put` or `.mjob` write therefore means **handoff submitted**,
not **job running**.

## Queue between nodes

`MigratableJobQueueChannelTransport` uses `QueueChannelFabric` remote queues. Its
payload is a Directory of strings/numbers rather than a process-local Rexx
object, so Queue Fabric's graph codec can persist and transmit it.  Placement
identity and ownership epoch are also placed in message headers.

A typical deployment has two logical routes:

- source `MIG.OUT` -> destination `MIG.IN`;
- destination `ACK.OUT` -> source `ACK.IN`.

The source transport binds a Job-to-Node destination node id to the corresponding
remote queue alias. `MigratableJobQueueWorker` claims the destination command,
passes the decoded instruction to `MigratableJobDestinationRunner`, queues the
acknowledgement, and acknowledges the command only after the acknowledgement is
accepted for return delivery.  Retrying a released command requires the local
destination executor to be idempotent for the same handoff id.

The qualification test uses `QueueInProcessTransport` so it is deterministic in
a single process.  The integration boundary is `QueueChannelFabric`; production
can use Queue Fabric's authenticated socket transport without changing the
Migratable Job payload or state machine.

## File / manual start

`MigratableJobFileHandoffTransport` writes a digest-protected `.mjob` control
manifest.  It does **not** hide checkpoint bytes inside the control file: large
job checkpoints remain Storage Fabric objects/files and retain their existing
verification/provenance.

The manual workflow is:

1. obtain `<handoff>.mjob` and the checkpoint object/file referenced by it;
2. copy them to the destination by the available mechanism (shared storage,
   removable/air-gap media, scp, operator-managed cloud copy, and so on);
3. invoke the destination application's `MigratableJobFileManualStarter`,
   optionally supplying the copied checkpoint path as an override;
4. if the instruction carries `sha256:...` transfer evidence, the local file is
   hashed before execution is permitted;
5. destination writes/returns a digest-protected acknowledgement;
6. return the acknowledgement to the source coordinator and call
   `acknowledge()`.

This path intentionally works with no live queue connection.  It is therefore a
real operating mode, not an error fallback.

## Direct mode

If no handoff transport is supplied to `MigratableJobCoordinator`, v0.2 retains
the v0.1 direct `resumeFromCheckpoint()` behaviour. This is useful when the
coordinator and destination runtime share the same control plane.
