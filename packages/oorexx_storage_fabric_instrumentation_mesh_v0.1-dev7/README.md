# ooRexx Storage Fabric Instrumentation Mesh v0.1-dev7

This package projects Storage Fabric operational state through `instrumentation.mesh/0.1` without creating a second telemetry or management authority.

## dev4

Adds boundary-hook classes suitable for direct use by Storage Fabric transfer, repair, provider, authority-checkpoint and Git provider code:

- `StorageInstrumentationHooks`
- `StorageInstrumentedTransfer`
- `StorageTransferCommitObserver`
- `StorageProviderStateObserver`

The core rule is **observe after the Storage state transition succeeds**. Instrumentation never decides replica safety, transfer commit, repair completion, provider admission, or authority recovery.

`StorageInstrumentedTransfer` emits start/progress only after the corresponding `StorageTransfer` transition succeeds. Completion is emitted only after `COMMITTED`; a VERIFIED transfer is not reported complete merely because byte verification succeeded.

High-cardinality StorageRef, pathname, provider locator and credential values are deliberately excluded from Mesh metric dimensions.

The package composes with the Instrumentation Mesh dev3 native Storage adapter so catalogue/workspace metrics remain owned there while this package adds durability, repair and operation observations.


## dev4 — durable replica repair work

Adds `storage.fabric.repair.queue/0.1`: under-protection is submitted to an existing Queue Fabric PERMANENT queue. Workers re-assess current Storage policy before and after repair, so stale/duplicate work is safe. See `REPAIR_QUEUE.md`.

## dev5 provider/topology reconciliation

Dev5 aligns the repair payload with the actual Storage Fabric dev23
`StorageReplicaRequirement` API and adds `StorageReplicaRepairReconciler`.
After Storage authority commits a provider/location availability transition, the
reconciler scans only catalogue objects associated with that provider, assesses
the current persisted requirement, and queues durable repair work only for real
protection deficits. It does not mutate provider state or promote telemetry to
authority. Duplicate notifications are suppressed in-process; replayed durable
work is still safe because execution re-assesses current policy before copying.


## dev6 — fail-closed protection policy and estate dependency reconciliation

Dev6 removes the implicit `StorageReplicaRequirement(1)` fallback. Missing
replica policy is now an explicit `policy_missing` condition; repair execution
refuses work without its authoritative requirement and topology reconciliation
queues nothing until either the object's persisted policy exists or an explicit
estate fallback is injected by the policy owner. Absence of policy is therefore
not permission to reduce recoverability.

Instrumentation Mesh is rebased to the reviewed dev8 source candidate, exact
SHA-256 `47402459e658da6ddb17c65c98010c0acd0e35d43b3a0b01c8c13c835f65d624`.
The existing metric/snapshot API remains usable. Where correlation/causation/
context evidence is supplied, it must be producer-supplied correlation; this
adapter must not infer correlation from timestamps, hosts, or payload content.

Storage target promotion is deliberately gated by properties rather than a
version label. `tests/check_storage_target.py` requires the protected large-file
precision and canonical unsigned codec plus the replica-policy API. The Library
`dev24` standards report currently fails and does not prove the divergent
large-file/backup-floor lines were merged, so dev24 is not treated as canonical
by this package. The Git `dev23-precision1` tree is useful precision evidence,
but its stale internal version metadata and remaining house-rule violations mean
it is an overlay candidate, not a silently promoted release.


## dev7 — exact Queue Fabric CLAIM/ACK/NACK worker

Dev7 removes the remaining placeholder around worker lifecycle. The adapter now
binds the current Queue Fabric dev6 contract directly:

- `claim(queueName, workerPrincipal)`
- `ack(queueName, packageId, claimToken, workerPrincipal)`
- `nack(queueName, packageId, claimToken, workerPrincipal)`

The claimed Queue Fabric package is the authority for `packageId` and
`claimToken`; the Storage worker never manufactures either value. Successful
Storage repair is ACKed only after `StorageRepairExecutionBoundary~execute()`
returns success. A semantic repair failure is NACKed for Queue Fabric retry /
backout / dead-letter handling. ACK failure after a successful repair is surfaced
as `ACK_FAILED_AFTER_REPAIR` rather than retrying through a second authority
path; replay remains safe because repair execution re-assesses current Storage
policy and already-satisfied work is a no-op.
