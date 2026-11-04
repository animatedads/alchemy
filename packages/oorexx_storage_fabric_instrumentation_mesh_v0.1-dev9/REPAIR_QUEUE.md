# Durable Storage replica repair queue — dev4

API: `storage.fabric.repair.queue/0.1`

Replica deficits are durable work, not transient callbacks. `StorageRepairQueueBinding` submits a `storage.fabric.repair.work/1` object to an existing Queue Fabric `PERMANENT` queue with `persistent=.true` and a caller-supplied deterministic repair id as correlation id.

Authority stays separated:

```
topology observation
  -> Storage replica-policy assessment
  -> durable STORAGE.REPAIR work
  -> Queue Fabric CLAIM
  -> re-resolve StorageRef
  -> re-assess CURRENT policy
  -> choose eligible destination through injected planner
  -> copy / independent verification / Storage admission
  -> re-assess policy
  -> ACK only after policy is satisfied
```

If the object is already protected when the worker receives the request, the repair is a successful no-op. A stale queue item therefore cannot force gratuitous movement.

The package deliberately does not guess the current Queue Fabric `claim/ack/nack` argument signature. Queue Fabric owns that worker lifecycle; `StorageRepairExecutionBoundary~execute(payload)` is the semantic function invoked *between* CLAIM and ACK. A current Queue Fabric adapter must ACK only after `execute()` returns `ok=.true`; execution failure is NACK/retry according to Queue Fabric policy.

Instrumentation Mesh receives `repairRequired` only after Queue Fabric accepts the durable package, and `repairSatisfied` only after Storage's current policy assessment succeeds. Telemetry never grants replica admission.

## Provider/topology reconciliation (dev5)

`StorageReplicaRepairReconciler` is called *after* Storage Fabric has committed a
provider/location availability change. It never declares a provider offline and
never mutates catalogue authority itself. It asks the current catalogue for
objects that mention the provider, reads each object's current persisted replica
requirement, assesses only currently AVAILABLE+VERIFIED+SAFE locations, and
submits durable repair work only for objects that are actually under-protected.

Repeated notifications in one process are suppressed by a deterministic repair
key. Replayed/duplicate durable work remains safe because the execution boundary
re-resolves and re-assesses the object before copying; already-satisfied work is
a successful no-op.


## Missing policy handling (dev6)

No implicit one-replica safety floor exists in the repair adapter. If a persisted
object requirement cannot be resolved, reconciliation reports `policyMissing`
and does not enqueue work. An estate owner may inject an explicit fallback
`StorageReplicaRequirement`; that is an authority decision and is therefore
visible configuration, not an adapter default.

A claimed repair item must carry the requirement that caused it to be queued.
Workers fail closed with `REPLICA_REQUIREMENT_MISSING` if that requirement is
absent instead of substituting `StorageReplicaRequirement(1)`.


## Exact Queue Fabric worker lifecycle (dev7)

`StorageRepairQueueWorker~processOne` now owns the small adapter between Queue
Fabric and the existing semantic execution boundary:

```
claim(queue, principal)
    |
    v
package.payload -> StorageRepairExecutionBoundary~execute()
    |                         |
 success                    failure
    |                         |
ack(packageId, token)      nack(packageId, token)
```

The claim token is read from the claimed Queue Package. It is never reconstructed
from correlation id, repair id, queue sequence or telemetry. Queue Fabric remains
responsible for delivery count, backout threshold, dead-letter movement and
durable recovery.

If ACK fails after Storage has already satisfied the repair, the worker reports
`ACK_FAILED_AFTER_REPAIR`. It does not guess whether an uncertain second ACK or
NACK would be safer. Re-delivery is semantically safe because the execution
boundary re-resolves the object and returns `ALREADY_SATISFIED` before movement.


## Destination planner (dev8)

The repair queue no longer stops at an abstract planner callback.
`StorageRepairDestinationPlanner` is the concrete policy/provider seam.

Before moving bytes it simulates each candidate's durable location and calculates
bounded gain against the current requirement:
- required replicas;
- distinct vendors;
- distinct sites;
- distinct failure domains.

A candidate with zero policy gain is rejected even if it has the highest
performance preference. After source materialisation, the selected provider must
return a verified durable `StorageLocation`; only then is it added to the
object. The surrounding execution boundary performs the final authoritative
policy reassessment.

Source materialisation remains injected so the Storage XTP networking work can
supply the exact verified local bytes without the repair planner acquiring
carrier, socket, route or MI/MU authority.


## Peer source materialisation (dev9)

Replica repair can now source bytes from the existing Storage peer protocol
without making the peer cache a durable location.

`StoragePeerRepairSourceResolver`:
1. selects an allowlisted peer backed by current AVAILABLE+VERIFIED object
   location evidence;
2. allocates an unused path beneath a pre-created staging root;
3. invokes `StoragePeerMaterialiser~materialise()`;
4. requires its `VERIFIED` result and exact StorageRef SHA-256;
5. returns a temporary `StorageRepairSourceResult`.

The destination planner deletes that temporary staged source after the provider
store operation. The verified peer materialisation therefore remains a transfer
source only; the provider's verified returned StorageLocation is the replica that
may satisfy durability policy.
