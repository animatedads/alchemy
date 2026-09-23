# Managed Job-to-Node placement — `migratable.job.placement/1`

Migratable Job v0.2.4 adds a standard managed surface for the initial placement
of a `NEW` migratable workload.  It exists so callers do not have to invoke
`JobNodeAllocator`, then invent their own lease checks, then call the standard
starter independently.

The authority boundary is unchanged:

- Job-to-Node owns eligibility, admission, placement leases and ownership epochs.
- `MigratableJobManagedPlacementTool` orchestrates those APIs; it does not make
  an independent placement decision.
- `migratable.job.start/1` owns idempotent process entry after placement.
- Migratable Job's migration coordinator continues to own planned destination
  handoff orchestration and uses Job-to-Node directly at that authority boundary.

## Operations

`PLAN`
: Read-only eligibility/ranking.  It uses the same capability registry,
  eligibility policy and scoring policy supplied to the authoritative allocator.
  It never reserves admission and never claims ownership.  `recommendedNodeId`
  is advisory only.

`CHECK`
: Calls `JobNodeAllocator~verifyLease()` against the workload's exact native
  `JobPlacementRequest`.

`ALLOCATE`
: Calls `JobNodeAllocator~allocate()`.  A retry which encounters the same
  still-current lease and verifies the same request is reported as
  `PLACED_REPLAY`; a second ownership epoch is not created.

`START`
: Requires an exact, current, verified placement lease before entering the
  standard starter.  The reference local executor additionally requires the
  lease node to equal the local node.  Remote execution is represented by the
  replaceable `MigratableJobPlacedStartExecutor` seam.

`ALLOCATE_START`
: Convenience composition of `ALLOCATE` then `START`.  If start fails or is
  ambiguous, the placement is deliberately retained and the result is
  `START_FAILED_PLACEMENT_HELD`.  The tool never guesses that a runtime side
  effect did not occur.

`RELEASE`
: Explicitly releases the Job-to-Node placement.  This is the cleanup path after
  the caller has established that no execution is running.

## Workload binding

The placement request is not supplied independently to the tool.  It comes from
`MigratableJobStarterApplication~definition(startRequest)`, whose
`MigratableJobDefinition~placementRequest` is the same authority-bearing
`JobPlacementRequest` used by the rest of Migratable Job.  Job, definition and
partition bindings are checked before placement.

Managed initial placement accepts `NEW` only.  `RECOVER` and `HANDOFF` keep their
existing recovery and committed-migration authority paths.

## Audit evidence

`MigratableJobPlacementAuditStore` is an append-only SHA-256 protected evidence
log with API `migratable.job.placement.receipt/1`.  A receipt records operation,
result code, placement ID, node, ownership epoch, start ID, execution reference,
request digest, whether the placement remains held, time and detail.

The audit log is evidence, not authority.  Placement validity is always obtained
from Job-to-Node.

## Recommended deployment surface

For initial jobs expose the managed placement tool rather than exposing the raw
standard starter as the ordinary operator/application entry point:

```
PLAN -> ALLOCATE -> CHECK -> START
             \-> on retry: PLACED_REPLAY

ALLOCATE_START failure
  -> START_FAILED_PLACEMENT_HELD
  -> establish runtime state
  -> explicit RELEASE only when safe
```

This preserves the useful separation introduced by `migratable.job.start/1`:
the starter still is not a scheduler, while the normal initial-start path can no
longer accidentally omit placement verification.
