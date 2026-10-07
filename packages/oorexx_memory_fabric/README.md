# ooRexx Memory Fabric v0.1-dev6

This is the first service-layer cut from the earlier in-process clustered-memory proofs.

## Contracts

- `memory.fabric/0.1`
- `registered.job.economic/0.1`

## What this cut adds

`MemoryFabricRegistry` gives an MU a stable discovery binding for a logical Memory Fabric service. The current provider can be:

- the MU itself (`kind=MU`), or
- an MI hosted on that MU (`kind=MI`).

An MI provider is intentionally compatible with being managed/reconstructed by RTO/RTO2. The stable Memory Fabric identity is separate from provider identity and endpoint.

Providers expose capacity, committed bytes, locality facts, provider state (`ACTIVE`, `SPARE`, `DRAINING`, `OFFLINE`), allocation state and fencing generations. SPARE remains on-mesh and discoverable but is not chosen for ordinary allocations unless explicitly allowed.

Blocks carry provider identity, generation and provider owner epoch. Advancing a provider membership epoch fences blocks published by an older incarnation.

## Execution locality

The fabric does not implement transparent remote pointers. It preserves the earlier rule: resolve the block owner and move/dispatch execution toward resident memory. Job-to-Node remains the placement/admission authority.

The recovered prototype `cluster_big_memory_v0.1.cls` is included unchanged under `upstream/` as evidence of the earlier executable semantics: stable logical indexes, physical offsets, generation fencing, spare-extent reuse, directed reads, local parallel method execution and explicit materialisation.

## Registered Job economic hold

`RegisteredJobEconomicHold.cls` is deterministic scheduling-policy support, not an LLM polling loop and not a second queue authority. It accepts already-observed commissioning offers and optional ML price-forecast evidence and returns one of:

- `RUN_EXISTING`
- `RUN_COMMISSIONED`
- `ECONOMIC_HOLD`
- `DEADLINE_RUN`
- `NO_ELIGIBLE_OPTION`

Existing idle capacity is preferred when it satisfies hard minima, even when it has less memory headroom or lower speed. A price forecast may recommend holding a Registered Job until the target is expected, but `latestStart` overrides that hold.

## Management / Intentions

`FabricManagementIntegration` exposes ordinary state objects suitable for dynamic Intention discovery and management presentation. This package deliberately does not modify Coding Intentions or hard-code cloud SKUs. A commissioning service can turn a semantic requirement such as “64 GiB for one hour, same site preferred, Spot allowed” into provider offers.

## Environment qualification

Run:

```sh
tests/environment_test.sh
```

Set `REXX_BIN` if ooRexx is installed under another executable name.

The script exercises the real ooRexx runtime, MU-provider discovery, MI-provider discovery, ACTIVE/SPARE selection, owner-epoch fencing, idle-capacity preference, economic hold, target-price start and latest-start override.


## v0.1-dev2 — execution follows memory and storage

The placement model is now deliberately LPAR-like in one architectural respect: a Registered Job is placed into a resource context formed around suitable memory and storage rather than treating those resources as afterthoughts attached to an already-selected compute node.

`MemoryFabricCapacityPlanner` can satisfy one logical request from multiple providers while retaining every provider boundary. A 64 GiB requirement can therefore be planned as two 32 GiB same-site providers. The result is a segmented logical capacity plan, not transparent cache-coherent remote pointers.

`registered.job.execution-context/0.1` combines:

- Job-to-Node hard eligibility supplied as an authoritative input;
- ordered Registered Job execution profiles;
- Memory Fabric capacity/locality plans;
- Storage Fabric locality/workspace/durability evidence;
- existing idle-node capacity;
- commissioning offers;
- deterministic economic hold / latest-start policy.

It returns an advisory action: `RUN_EXISTING`, `COMMISSION`, `ECONOMIC_HOLD`, or `NO_CONTEXT`. It never issues a Job-to-Node lease itself.

This creates the desired flow:

```
Registered Job
  -> discover memory + storage topology
  -> test existing execution contexts
  -> use a declared degraded profile during idle capacity when acceptable
  -> otherwise evaluate commissioning
  -> optionally remain on economic hold
  -> Job-to-Node authoritatively leases the chosen execution node
```

The Storage Fabric side already treats locality as evidence rather than placement authority and supports node-scoped workspace planning; this package follows that boundary rather than duplicating Storage Fabric allocation.


## v0.1-dev3 — collection epoch snapshots

The earlier object-memory proof is now promoted into `src/MemoryFabricObjectMemory.cls`. Parallel scans, locality-preserving method execution and explicit materialisation no longer rely on an undocumented quiescent collection.

Every successful placement or pull advances a monotonic collection epoch. `BigMemory~snapshot` captures the live membership and exact address generations at one epoch. Snapshot operations use that immutable membership even when later mutations pull objects or reuse their physical extents. The live address resolver still rejects the old generation.

The snapshot contract deliberately freezes **membership and address identity**, not arbitrary mutable fields inside resident application objects. Deep application-state immutability remains the responsibility of the object/domain contract.

The default operations (`containsParallel`, `parallelMessage`, `materializeAll`) take a fresh snapshot at entry. Explicit `containsParallelAt`, `parallelMessageAt`, and `materializeAllAt` let a caller reuse one captured epoch across related reads.

This is a Memory Fabric semantic contract. It does not define transport, packetisation, carrier selection, compression or XTP behaviour.


## v0.1-dev4 — native MU memory-block bag

`memory.fabric.block/0.1` adds a second kind of fabric bag for the RexxOS/MI-on-MU topology. The memory container is owned on the MU and exposed to an MI as page-aligned large blocks. Memory Fabric retains block allocation, identity, generation, owner-epoch and recovery semantics; the native connector owns only the byte mapping/copy fast path.

The supplied Linux native backend maps the external container with `MAP_SHARED`, requests transparent huge-page treatment with `MADV_HUGEPAGE`, and provides bounded native read/write/copy/zero/flush primitives. Blocks are aligned to a configurable large-page size (2 MiB by default), released extents are reused, and generation fencing rejects stale handles after reuse.

The production QEMU path is deliberately an implementation below this ABI: a shared-memory/DMA-capable QEMU device may map the same MU container into the MI and perform page/block movement without changing `MemoryBlockBag`. The generic connector does not falsely label host `memcpy()` as DMA.

This gives Memory Fabric an alternative bag alongside object-resident/provider memory: large block storage whose natural unit is a mapped page extent rather than a Rexx object.


## v0.1-dev6 — provider lifecycle and MI attachment fencing

Provider lifecycle is now an executable Memory Fabric contract rather than descriptive state. `transitionProvider` generation-controls ACTIVE/SPARE/DRAINING/OFFLINE transitions. DRAINING closes ordinary allocation while retaining access to already-owned blocks; OFFLINE removes the provider from resolution. `reincarnateProvider` advances the membership epoch, which fences blocks from the previous provider incarnation.

`lifecycleObligations` projects the required action for resident blocks by recovery class: VOLATILE drops, RECONSTRUCTABLE rebuilds from its reference, REPLICATED verifies/promotes a replica, and CHECKPOINTED restores from its checkpoint. It does not perform Storage Fabric operations itself.

The MU memory-block bag now has the same lifecycle boundary and explicit MI attachments. An attachment binds `(bagId, MU, MI, bag owner epoch, MI epoch)`. DRAINING preserves existing attachments/blocks but refuses new allocations; OFFLINE denies attachment validation; advancing the bag owner epoch invalidates old block handles and every old MI attachment. An MI must attach again to the new bag incarnation.

This deliberately separates control from payload movement. Memory Fabric defines bag/attachment identity and authority. The MI↔MU control path may be carried by XTP in the system architecture, while large block payload movement remains the QEMU/shared-memory/DMA path below `memory.fabric.block/0.1`. No XTP packet or socket semantics are introduced here.
