# Storage Fabric dev19 — two-centre Audio failover topology

Execution placement and durable replica placement are deliberately independent.

```text
CENTRE C / VENDOR A                         CENTRE E / VENDOR B
mu-ed209c                                   mu-ed209e (example)
  verified StorageRef X                       verified StorageRef X
  mi-01ed209c ACTIVE audio                     mi-06ed209e may process another range
       |                                                  |
       +---------------- same immutable X ----------------+

                         execution failover
                               |
                               v
                         mu-ed209d
                         mi-04ed209d
                         materialise X from any surviving verified centre
```

The failover execution node does not need a pre-existing durable copy. It needs
network reachability through the estate SocketProvider to a surviving Storage
peer/provider that can materialise the exact pinned `StorageRef`.

For this deployment the source policy is:

- required durable replicas: 2
- distinct vendors: 2
- distinct sites/centres: 2
- distinct failure domains: 2

`StorageReplicaRequirement~new(2,2,2,2)` expresses that rule. Two disks, VMs or
Storage locations in one physical centre do not satisfy it.

When CENTRE C is lost, the policy becomes DEGRADED because only one safe copy is
currently reachable. That does not block recovery of mi-04ed209d: it can
materialise X from CENTRE E. Storage should then create and verify a replacement
replica in a new independent centre before the object is considered fully
redundant again.

Parallel processing is safe when workers consume a pinned immutable source.
Each job/partition carries the same StorageRef plus its own range/partition and
Audio safe-point state. Derived outputs are new StorageRefs. No worker owns the
source pathname, and no migration checkpoint records a provider-local path.
