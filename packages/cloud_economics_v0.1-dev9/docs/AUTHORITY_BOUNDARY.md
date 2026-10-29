# Cloud Economics dev2: estate-native authority boundary

The normal `cloud-cost watch` remains an isolated **paper simulator** consuming
normalised read-only offers and job rows. It is intentionally not connected
to a live allocator. Its `approved`, `capacity` and `fabric_ok` columns are
assertions supplied by an upstream adapter, not proof created by economics.

The new `src/CloudEconomicsAuthority.cls` is the first object-rich path
for evaluation inside the real estate. This is not a duplicate job scheduler.

## Object interface

`CloudEconomicAuthorityPlanner~evaluate(job, offers, now, intentions,
workload, context=.nil, history=.nil, fabricPlan=.nil,
nodeEvidence=.nil, nodePolicy=.nil, fabricRegistry=.nil)`

Inputs:

- `intentions`: an existing `GeneralizedComputeIntentionProvider`, bound to
  actual compute, allocation, WLU and router assessment adapters. Its
  `planAdmittance()` is called once; candidates not in `admissibleCandidates`
  are rejected before price comparison. A returned resource must expose
  `~offerId` or `~id`, matching an offer identity exactly. No discovery adapter
  is fabricated in this module.
- `offers`: normalised market/economic snapshots; no duplicate IDs or `+`
  separators. The planner works on copies and never modifies upstream quotes.
- `fabricPlan` **and** `fabricRegistry`: real Memory Fabric object references.
  Split-memory ranking requires a complete, two-fragment `MemoryFabricCapacityPlan`
  within SAME_SITE locality (numeric bound 40), and every fragment must map to
  an observed `MemoryFabricRegistry` provider with a provider ID and site ID
  matching the corresponding economic quote. Both quotes must already be
  marked fabric-compatible by the originating capacity authority. One node
  remains the CPU execution owner; its CPU requirement is not added to that
  of the memory contributor. Segmented memory is not contiguous address space.
- `nodeEvidence` (optional): quote ID -> directory with `binding`, `request`,
  `capability`, and `capacity`. The binding must contain the exact `offer_id`
  and physical `node_id`. `request` is a `JobPlacementRequest`; `capability` a
  `NodeCapabilityStatement`; `capacity` a `NodeCapacityObservation`.
  `nodePolicy` is the actual `JobNodeEligibilityPolicy`. When `nodeEvidence` is
  supplied, offers without valid evidence are rejected, not assumed eligible.
  The policy receives the native request, capability and observation at the
  requested current epoch in milliseconds.

The node gate independently requires the placement request to name the same
job, to request **at least** the economic job's installed/free memory and
installed/available CPU, and to carry the economic runtime and jurisdiction
requirements. GPU-quantity proof is not available through this generic JNA
path, so GPU jobs are rejected when the node-evidence gate is selected.

Returns `CloudEconomicAuthorityHandoff` with `~route`, `~selectedCandidates`,
`~decision`, `~status` and `~explanation`. Status
`ADVISORY_HANDOFF_READY` retains the **original** candidate objects, rather
than serialising/reconstructing them. Its `~dispatchable` is always `.false`.
Actual allocation, WLU reservation, lease signing, deployment, data movement,
execution, checkpoint, migration and cloud purchasing must go through their
own authorities with current proofs. A paper handoff never entitles these
operations or extends the observation's lifetime.

## Real tests

`tests/test_authority_bridge.rex` links the real upstream Generalized Compute
Intentions, JobNodeAllocator 0.6-network3, and Memory Fabric dev7 classes. It
checks both veto and admissible routes, matching and missing memory plans,
original candidate identity, same-site memory requirement, runtime/jurisdiction,
actual JNA eligibility, expired capacity, false binding, job identity,
understated memory, and non-mutation. Read-only tests build synthetic capacity
observations but invoke the **actual** authority classes.

The allocator's `JobNodeAllocator.cls` declares `::requires "crypto.cls"`.
Provide the exact compatible Crypto package root via `CRYPTO_ROOT`; no fallback
stub or unverified replacement of Crypto is included. Full tests use:

```
export GENERALIZED_INTENTIONS_ROOT=/path/to/oorexx_generalized_compute_intentions_v0.1-dev3
export JOB_NODE_ALLOCATOR_ROOT=/path/to/job_node_allocator_v0.6-network3
export MEMORY_FABRIC_ROOT=/path/to/oorexx_memory_fabric_v0.1-dev7
export CRYPTO_ROOT=/path/to/compatible-crypto-package
./tests/run.sh
```

`REXX_PATH` must resolve those exact classes plus the cloud economics package.
The source requires those packages **only** for callers using the optional
object-level interface; standalone TSV paper monitoring does not load them.

## Accounting and concurrency

`cloud-cost audit` compares each `PAPER_BUY` receipt to exactly one expense and
one equal opposite commitment posting, including quote IDs and amounts. Missing
halves are repairable on the next tick from an immutable receipt; duplicates,
orphans and altered amounts are not silently repaired. The tick refuses new
commitments on detected corruption.

`cloud-cost` holds `$CLOUD_ECONOMICS_STATE/.economic.lock` via `flock` for each
state-reading/writing command, preventing concurrent ticks, poll/ingest races,
and submission races *on a single filesystem*. The `watch` loop does not hold
this lock while sleeping. This is NOT distributed leader election, a quorum
ledger, or multi-host/HA fencing. For estate-wide continuous operation, the
existing Queue Fabric/RTO2 ownership and failover authorities must own which
node is the active economic writer.

## Deliberately unimplemented

- No verified economic entitlement to provider capacity, purchase, payment,
  cancellation, quota, account invoice or cloud credential use.
- No job checkpoint or migration command, no assumption that VM memory can
  become distributed RAM without fabric-specific allocation and performance
  evidence.
- No cost forecast model trained on verified multi-provider market history:
  dev1's EWMA/slope is a versioned statistical baseline only.
- Only Azure public retail price observation is implemented (network-unverified
  in this container). The other 22 registered sources need qualified adapters;
  `UNCONFIGURED` does not mean observed.
