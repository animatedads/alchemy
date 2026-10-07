# Changelog

## 0.1-dev6

- executable provider ACTIVE/SPARE/DRAINING/OFFLINE lifecycle transitions
- provider reincarnation advances membership epoch and fences old blocks
- recovery-class lifecycle obligation projection
- MU memory-block bag lifecycle gating
- MI attachment leases fenced by bag owner epoch and MI epoch
- explicit transport boundary: XTP may carry control, QEMU/DMA carries large block payload below connector ABI

# CHANGELOG

## 0.1-dev3

- Promoted the clustered object-memory implementation from `upstream/` into `src/MemoryFabricObjectMemory.cls`.
- Added monotonic collection epochs for successful ASSIGN and PULL mutations.
- Added immutable `MemoryCollectionSnapshot` membership views with captured logical index, module, offset, generation, item identity and pinned object reference.
- Made parallel scan, local method execution and explicit materialisation snapshot-based by default.
- Added explicit `...At(snapshot, ...)` operations so callers can hold one epoch across multiple operations while live placement/pull continues.
- Preserved generation fencing: a snapshot may retain an old object while the reused physical address remains invalid for live resolution.
- Reject snapshots created by another `BigMemory` instance.
- Clarified that snapshots freeze collection membership/address generations, not arbitrary mutable state inside application objects.
- Added ooRexx 5.3.0 r13196 qualification for pull + spare-extent reuse across a retained snapshot.
- Fixed service-layer byte arithmetic to use 20-digit numeric precision; the dev2 64 GiB multi-provider test otherwise rounded large byte counts inside ooRexx methods.
- Corrected the economic-hold regression fixture so its commissioning offer remains valid at the asserted latest-start time.
- Repaired dev2 execution-context qualification defects: non-short-circuit `.nil` guards, missing direct class dependencies, and use of Rexx special variable `RESULT` as a test local.

## 0.1-dev2

- Added multi-provider Memory Fabric capacity planning; one logical requirement may span several explicit provider fragments.
- Added locality bounds and provider-count bounds to multi-provider plans.
- Added `registered.job.execution-context/0.1`.
- Added ordered execution profiles so existing idle nodes may run jobs with explicitly accepted lower headroom/speed.
- Added Storage Fabric evidence input for workspace fit, materialisation cost and durable-output admissibility.
- Preserved Job-to-Node hard eligibility as an absolute external authority.
- Added commissioning/economic-hold integration without creating a second scheduler.
- Added regression probes for 32+32 GiB same-site planning, degraded idle execution, forecast hold, latest-start commissioning, and hard-eligibility rejection.


## 0.1-dev1

- Promoted the earlier in-process clustered-memory proof into a first explicit `memory.fabric/0.1` service contract.
- Added stable MU discovery bindings separate from current provider identity.
- Added MU-hosted and MI-hosted provider forms.
- Added ACTIVE/SPARE/DRAINING/OFFLINE provider state and ACCEPTING/RESERVED/DRAINING/CLOSED allocation state.
- Added same-MU / same-machine / same-site / remote locality scoring.
- Added provider membership epoch and provider generation fencing.
- Added MemoryBlockRef owner-epoch and block-generation validation.
- Added explicit block recovery classes: VOLATILE, RECONSTRUCTABLE, REPLICATED and CHECKPOINTED.
- Added deterministic Registered Job economic evaluation with existing-idle-capacity preference, target/maximum cost, Spot permission, ML forecast evidence and latest-start override.
- Added management projection seam for Intention discovery/presentation without changing Intention semantics.
- Included complete environment qualification script.

## 0.1-dev4
- Added `memory.fabric.block/0.1` MU-resident native memory-block bag.
- Added 2 MiB-default large-page alignment, free-extent reuse and generation fencing.
- Added native mmap/shared-memory connector with huge-page advice and bounded block operations.
- Kept QEMU/DMA mechanics below the connector ABI; generic backend makes no false DMA claim.
- Added native connector qualification to the full environment test.
