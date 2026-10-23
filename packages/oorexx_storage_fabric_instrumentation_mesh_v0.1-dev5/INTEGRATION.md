# Storage Fabric boundary integration

Recommended Storage Fabric dev23 wiring is dependency injection, not monkey patching.

```rexx
identity = ... /* Instrumentation identity */
events = .StorageFabricMeshEvents~new(identity)
hooks = .StorageInstrumentationHooks~new(events)

/* transfer construction */
t = hooks~newTransfer(id, ref, sourceLocation, targetProvider, targetLocator, size)

/* repair authority */
hooks~repairRequired(repairId, reason)
... verify/admit replacement replica through Storage Fabric ...
hooks~repairSatisfied(repairId)

/* provider observation */
providerObserver = .StorageProviderStateObserver~new(events)
providerObserver~observe(providerId, providerKind, currentState)
```

Instrumentation calls belong after the authoritative transition they describe. In particular:

- `repairSatisfied` follows verified replica admission and policy reassessment.
- `authorityCheckpoint` follows durable checkpoint commit.
- `authorityRecovered` follows successful authority reconstruction.
- Git store completion follows remote-ref confirmation plus object verification.
- transfer completion follows Storage `COMMITTED`, not merely `VERIFIED`.

The adapter must remain optional: absence or failure of instrumentation must not corrupt Storage state or invent a failed Storage operation. A production integration may isolate emitter exceptions at the call site if the configured Mesh sink can throw.


## Durable repair integration

Use `StorageRepairQueueBinding` with the existing authoritative `ObjectQueueManager`; do not create a second manager over the same store. Queue Fabric owns CLAIM/ACK/NACK and crash recovery. Invoke `StorageRepairExecutionBoundary~execute()` after CLAIM and ACK only after it returns success.
