# Job-to-Node alignment — FD Door Micro Motion v0.2-dev5

This rebase is against the exact **ooRexx Job-to-Node Allocator v0.6** core archive:

- API: `job.node.allocator/0.6`
- SHA-256: `58f23b90824d73b584ea5bfce4ac5805a537ab0283508ee6c81ccf2458f80ead`

Migratable Job v0.2.4 does not replace that authority. Its `migratable.job.placement/1` surface orchestrates the native Job-to-Node calls.

## Native objects used

FD supplies a native `JobPlacementRequest` containing a `JobNodeRequirement`. Node/source observations are converted into `NodeCapabilityStatement` and `NodeCapacityObservation` entries in a `NodeCapabilityRegistry`. The authoritative allocator is `JobNodeAllocator` with a `JobNodeOwnershipRegistry`; durable authority is preserved by `JobNodeDurableJournal` / `JobNodeDurablePlacementManager`.

The normal NEW path is therefore:

```text
FD measured probe
  -> NodeCapabilityRegistry
  -> JobPlacementRequest
  -> JobNodeAllocator~allocate()
  -> ownership epoch + JobNodePlacementLease
  -> durable JobNode checkpoint
  -> JobNodeAllocator~verifyLease()
  -> MigratableJobManagedPlacementTool CHECK
  -> MigratableJobManagedPlacementTool START
  -> migratable.job.start/1
  -> private FD worker
```

No FD code creates a placement ID or ownership epoch. `PLACE-*` and `ownershipEpoch` are produced by Job-to-Node. A retry seeing the same current placement is accepted by Migratable Job only when the exact native lease still passes `JobNodeAllocator~verifyLease()`.

## Authority invariants retained from Job-to-Node v0.6

- hard eligibility is evaluated before optimisation;
- capability and transient capacity are separate evidence;
- requirement, capability and capacity digests are lease-bound;
- owner identity and allocator policy generation are checked on verification;
- offline/revoked nodes and expired capacity observations fail verification;
- ownership epochs fence prior owners;
- durable restart restores allocator sequence and highest ownership epochs;
- a corrupt committed durable snapshot fails closed;
- a failed or ambiguous process start does **not** imply that the placement is safe to release.

`MigratableJobPlacementAuditStore` is evidence only. The Job-to-Node lease and durable ownership state remain authoritative.

## Current campaign deployment

For the fixed C/D/H/I campaign assignment, each measured probe includes a job-specific assignment tag. The central authority therefore evaluates the assigned node under the same native eligibility/lease machinery rather than accepting operator-entered placement values. The canonical Job-to-Node journal is kept centrally; worker-side copies are verification snapshots only and must not be used for independent allocation.

If a remote/network Job-to-Node service is deployed later, it should front the same v0.6 authority semantics; it must not create a second allocator or second ownership lineage.
