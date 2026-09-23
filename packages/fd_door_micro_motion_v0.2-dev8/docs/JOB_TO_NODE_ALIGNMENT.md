# Job-to-Node alignment — FD Door Micro Motion v0.2-dev8

FD is aligned to the exact ooRexx Job-to-Node Allocator v0.6 authority:

- API `job.node.allocator/0.6`
- exact core archive SHA-256 `58f23b90824d73b584ea5bfce4ac5805a537ab0283508ee6c81ccf2458f80ead`

The qualified network facade is `job_node_allocator_v0.6-network1`, API `job.node.allocator.network/0.1`. It transports PLAN/ALLOCATE/CHECK/RENEW/RELEASE and does not become placement authority.

Migratable Job v0.2.5 orchestrates that authority through `migratable.job.placement/1` and, for a remote initial NEW execution, `migratable.job.remote-start/1`.

## Production boundary

QueueRexx owns the authority service and inter-machine wiring. FD sees an allocator/client contract, not ports or transport topology.

```text
FD workload requirements
  -> Migratable Job managed placement
  -> Job-to-Node network client
  -> QueueRexx-managed Queue Fabric route
  -> central JobNodeNetworkAllocatorService
  -> exact JobNodeAllocator v0.6
  -> native JobNodePlacementLease
  -> destination remote-start lease recheck
  -> standard starter
```

No FD code may manufacture `placementId`, `ownershipEpoch`, admission authority, release semantics, or an alternate ownership lineage.

## Authority invariants

- hard eligibility precedes optimisation;
- capability and transient capacity are distinct evidence;
- requirement/capability/capacity digests are lease-bound;
- owner identity and allocator policy generation are verified;
- offline/revoked nodes and expired observations fail verification;
- ownership epochs fence prior owners;
- network request replay does not create a new authority transition;
- a failed/ambiguous/pending process start does not imply safe release;
- worker-side direct execution is not a placement fallback.

The FD scientific state and Job-to-Node authority state remain separate. Migration checkpoints preserve analyser state; Job-to-Node preserves who is permitted to execute it.
