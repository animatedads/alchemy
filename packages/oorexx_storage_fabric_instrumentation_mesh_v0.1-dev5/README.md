# ooRexx Storage Fabric Instrumentation Mesh v0.1-dev5

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
