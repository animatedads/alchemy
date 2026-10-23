# Storage Fabric multi-source ranged acquisition

Storage Fabric owns object identity, byte/chunk regions, source selection and re-planning. It does not own physical network addresses or XTP sequence numbers.

Example:

- `mi1-mu2` requests `audio1234.mp4`, region `[0,100MB)` through a named storage service.
- `sfu1-mu5` and `sfu1-mu7` each advertise the requested region.
- `normal.storage` says `per-context=30%`, `max-parallel=2`, `aggregate=60%`.
- Storage plans `mu5 -> [0,50MB)` and `mu7 -> [50,100MB)`.
- Each transport context receives the class and 30% cap. Receiver fan-in is two, so effective inbound may reach 60%, never above the class aggregate cap.

Discovery is abstracted by `StorageRangeDiscoveryPort`; XTP MULTI is a preferred implementation where available, but Storage Fabric does not require XTP. Replies identify logical peer/service identities only. IP addresses belong exclusively to the selected transport's route configuration.

## Control example

The example `examples/normal_storage_setup.rex` registers `normal.storage` and the named services `storage.range.search` / `storage.range.read`. Under NORMAL it sets 30% per context, fan-in 2, aggregate 60%. The same class contracts to 25%×2/50% aggregate when DEGRADED, 15%×1 when CONSTRAINED, and suspends in EMERGENCY.

A plan can then be inspected without exposing network addresses:

```
storagefetchctl.rex plan storage.range.read audio1234.mp4 0 100000000 normal \
  --offer sfu1-mu5:0:100000000 \
  --offer sfu1-mu7:0:100000000
```

Expected semantic result: two 50,000,000-byte slices, each capped at 30%, with 60% maximum aggregate inbound for the class.

## dev23 live capacity admission

A fetch plan can now be bound to an `OperationalCapacityGovernor` through `StorageCapacityAdmission`. Each planned source context receives an admission ticket for a named capacity domain such as `mi1-mu2.ingress`. `StorageFetchAdmission` preserves the logical slices while capacity/state changes reconcile the live tickets: rates contract with domain capacity, excess contexts are suspended rather than forgotten, emergency can reduce the admitted set to zero, and restoration can reactivate the retained contexts.
