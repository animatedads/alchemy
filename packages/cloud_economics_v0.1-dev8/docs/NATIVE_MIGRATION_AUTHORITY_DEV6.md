# Cloud Economics dev6 — native execution and placement evidence

This is an additional **read-only object interface**. It does not replace the
CLI watcher, and its presence does not upgrade file-based `migration-preview` or
`opportunities` to native-authorized decisions. A live estate integration must
call `CloudMigrationEstateBridge~evaluate` with actual in-process objects, or
obtain the same authorities via a separately configured Connect Selector
integration when its read-only service contracts are published. **No transport
is selected or invoked here.**

## Library sources inspected, 2026-10-09

- `job_node_allocator_v0.6-network3.zip` / same code in RTO2 Grid dev13:
  `JobNodeAllocator~verifyLease`, `JobNodeExecutionLifecycleRegistry~stateFor`,
  `JobNodeEligibilityPolicy~assess`, actual lease/requirement/observation objects.
- `oorexx_memory_fabric_v0.1-dev9.zip`: native
  `RegisteredJobExecutionContextPlanner~choose`, candidate/storage profile,
  capacity plan, locality/site and memory-plan completeness.
- `oorexx_architecture_intentions_v0.1-dev6.zip`: authoritative ownership and
  provenance of architectural capability decisions; **design-time**, not a
  runtime migration grant.
- `oorexx_connect_selector_v0.1-dev2.zip`: transport neutrality and explicit
  registration/route policies. Cloud Economics does not fork its transport
  selection or silently promote a route reference into an RPC permission.
- `rexxos_rto2_grid_v0.1-dev13.zip`: integrated runtime bundle includes the
  above allocator and Memory Fabric, plus dev5 economics snapshot. Dev6 remains
  independently packaged so the Grid owner can integrate it deliberately.

## Object interface

```rexx
result = .CloudMigrationEstateBridge~new~evaluate(running, routes, offers, now, -
  tariffs, sourceLease, sourceRequest, issuingAllocator, lifecycleRegistry, -
  sourceOfferNodeBinding, destinationJnaProofs, destinationJnaPolicy, -
  destinationExecutionContextPlans)
```

All additional inputs beyond dev5 are actual ooRexx objects. The *issuing*
allocator must be supplied; creating a new verifier with unrelated state is not
an authority check. `verifyLease()` checks current lease epoch/policy, capability
and capacity generations and digests, remaining lease validity, current owner
when configured, and signature when the issuer has proof authority configured.
Unsigned/default allocator deployments cannot make a cryptographic claim.
The source's original request must not understate the running job's CPU, memory,
residency or runtime. The lifecycle registry must have an unambiguous `RUNNING`
state, nonempty execution and evidence references, and observation freshness
within 300 seconds. Any uncertain or unobserved execution state is a hold.

A destination cannot enter the economic comparison unless its exact offer/node
binding, placement request, capability/capacity observation, and hard policy pass
`CloudEconomicNodeEvidenceGate`; it must additionally have an actual
`RegisteredJobExecutionContextPlan` with a complete Memory Fabric plan, memory
capacity, site alignment, locality/profile limits, hard eligibility, and
compatible storage evidence. A plan with action `COMMISSION` is marked as a
**prospective commissioning scenario**, not an acquired machine.

The unchanged dev5 comparison then ranks only gated routes by marginal future
cost and deadline. The result is a `CloudMigrationEstateHandoff` retaining the
real source lease/lifecycle and selected native destination proofs/context.
Every result returns `dispatchable=false`, `migrationAllowed=false` and
`purchaseAllowed=false`. A favorable route is **not** checkpoint consistency,
a transfer reservation, an authorization to transfer data, or source fencing.

States include:

- `EVIDENCE_HOLD`: missing, stale, mismatched or revoked source authority.
- `NATIVE_STAY_OR_HOLD`: source valid, but no admissible cheaper destination.
- `NATIVE_ELIGIBLE_ADVISORY`: placement and memory evidence checked; economic
  move favored; route/mobility permission still unverified.
- `NATIVE_COMMISSION_SCENARIO_ADVISORY`: forecast requires future commissioning.

No real cloud credentials, money, invoices, distributed locks or migration
operation are consumed by this module. The portable accounting daemon retains
its existing local writer lock; remote authority and accounting consistency
remain the responsibility of the relevant owner.

## Upstream lifecycle regression observed

Using the supplied ooRexx 5.3.0 r13196 debug runtime and the allocator
`v0.6-network3` Library package, the *upstream* test
`tests/test_execution_lifecycle.rex` fails at its first `observe` assertion:
`Object "RESULT" does not understand message "ACCEPTED"`. The method returns
a literal `RESULT` where its public `JobNodeExecutionReconcileResult` object is
expected. This needs a separate allocator-owner correction. Dev6 neither
patches nor ships a divergent allocator. Native bridge tests use the documented
`restore`/`stateFor` path with legitimate typed lifecycle-state objects to
exercise read-side policy, expiry, identity and uncertainty semantics; they do
**not** claim end-to-end live event-ingest qualification. A restored record is
only as trustworthy as the registry/journal authority that supplies it.

## Boundary for the next increment

Connect to the *owning* runtime's persisted execution evidence through its
published API (with owner/epoch verification), the checkpoint/restore semantic
contract, and source/destination fencing. Revalidate every source lease and
route after preparing a transfer. Verify compliance, budget, WLU and operational
approvals independently. Only then consider a distinct, explicitly authorized
commissioning or migration actuator. Until then, every paper decision is
non-effectful and never evidence of a completed job movement.
