# Runtime Placement and Admittance Layers Knowledge Sphere v0.2

This sphere documents the complete seam from semantic compute intent to authoritative placement and managed execution. It extends the original placement-layers sphere without changing the ownership of any underlying subsystem.

## Layering seam

```text
semantic workload / intention
        |
        v
Generalized Compute Intentions
  planned admittance route
  (evidence, never entitlement)
        |
        v
current authoritative revalidation
  compute capability + router + WLU + allocation
        |
        +--> WLU admission / reservation
        |
        +--> Job-to-Node placement / ownership epoch / lease
                         |
                         v
              managed execution target
              CPU / GPU / ZeroGPU / LLM / other
                         |
                         v
                Runtime Reference / provider
```

Instrumentation Mesh sits alongside this path as observation only. Health, freshness, state and operational events may affect preference or explanation, but never manufacture capability, admission, placement, lease validity, release authority or execution success.

## Core invariants

- **Plan is evidence, not entitlement.** A `PlannedAdmittanceRoute` is non-mutating and must be revalidated immediately before any authoritative mutation.
- **Dynamic discovery.** Candidate resources, provider health, WLU capacity, policy and allocator evidence are rediscovered; a prior plan is not a permanent action catalogue.
- **Rich objects survive.** Workload, requirements, resource, WLU demand/reservation and placement objects remain native objects rather than being flattened into command strings.
- **Hard eligibility first.** Security, legal, policy, capability and mandatory resource constraints are never outweighed by cost, speed or idle capacity.
- **WLU owns admission.** Ranking or planning cannot fabricate reservation authority.
- **Job-to-Node owns placement.** Ownership epoch, lease, fencing and release remain allocator authority.
- **Runtime observation is not release authority.** `RUNNING`, `ABSENT` or `UNKNOWN` evidence can explain state but cannot free a placement by itself.
- **Target generation must match.** Managed execution rejects a stale or mismatched target/capability generation even when a previous placement looked valid.
- **Replay ambiguity fails closed.** A claimed provider call with uncertain outcome remains held for reconciliation; it is not automatically replayed.
- **LLMs are compute resources, not a special routing exception.** Local/hosted models, accelerators, CPU, GPU and ZeroGPU can share the same planned-admittance semantics while retaining provider-specific capability requirements.

## Current evidence line

- Generalized Compute Intentions `v0.1-dev5` — object-preserving planning, Intention Service bridge, Mesh dev7 freshness/events, explicit revalidation contract.
- Work Load Units `v0.12` — work/capacity admission and reservation authority.
- Job-to-Node Allocator `v0.6-network6` — authoritative placement plus fail-closed network/lifecycle recovery; network6 runtime qualification remains separately pending in its own package evidence.
- RexxOS Managed Compute MU `v0.1-dev2` — downstream managed target binding and replay safety; production dispatch remains gated on durable replay/request infrastructure and membership-generation revalidation.
- Instrumentation Mesh `v0.1-dev7` — observation health/freshness and operational event timeline, never mutation authority.
- Runtime Reference `v0.4` — execution-location binding after admission/placement authority has been satisfied.

## Known remaining work

The sphere records rather than conceals current gaps: Job-to-Node network6 still needs its package-level runtime qualification, and Managed Compute MU dev2 must gain a durable replay ledger, durable Queue Fabric request/reply, atomic claim/provider idempotency, and RTO2 membership-generation revalidation before production dispatch is enabled.
