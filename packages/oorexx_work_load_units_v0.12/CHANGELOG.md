# Changelog

## v0.12

- Adopt `alchemy_objects_v0.7` across every long-lived WLU Alchemy object and migrate construction from compatibility `initAlchemy(...)` to the preferred non-virtual `self~init:super(...)` entrypoint.
- Upgrade WLU package metadata to `ALCHEMY-HOUSE-OBJECT-0.7`; STANDARD adoption now requires zero warnings and explicit `INIT` construction provenance, while `WLUAuthority` retains SECURE_READY qualification on r13196.
- Add SipHash authentication to `WLURouteAdvisoryResult`, covering the exact verified analytics cut, advisory policy thresholds, candidate assessments and recommendation.
- Add `WLURouteDecisionPolicy.cls` with sealed `WLURouteDecisionRules` for explicit AUTOMATED/OPERATOR semantics (`DENY`, `RECOMMENDED_ONLY`, `EVIDENCE_ELIGIBLE`, `DECLARED_CANDIDATE`).
- Use shared `institutional_policy_v0.1` for publication, authorship/approval identifiers, effective-time resolution, supersession, publication records and fixed-artifact execution-model gating rather than duplicating lifecycle mechanics in WLU.
- Add `WLUJobRouteDecisionGate`, a non-entitling policy evaluation boundary that rejects forged advisory evidence, resolves the operative policy by action time and returns authenticated `WLURouteDecisionEvidence` retaining the exact policy release/publication record and advisory MAC identity.
- Add explicitly labelled counterfactual route-policy evaluation plus outcome/trace comparison through `InstitutionalPolicyComparison`; counterfactual evidence never fabricates an operative publication record.
- Add `test_route_decision_policy.rex`, strengthen `test_route_advisory.rex` with advisory-proof verification, replace v0.5 adoption coverage with warning-free v0.7 construction/adoption checks, and add `examples/policy_governed_route_decision.rex`.
- Keep advice and policy evaluation non-authoritative: neither surface can reserve/spend WLU, acquire hierarchy/throughput capacity, promote standby work or invoke a provider.

## v0.11

- Add `WLURouteAdvisory.cls`, a non-authoritative evidence-weighted route recommendation layer over verified route analytics snapshots.
- Add explicit `WLURouteAdvisoryPolicy` gates for minimum sample count, conservative 95% SUCCESS lower bound, conservative 95% over-expected upper bound, and optional observed average-WLU cap.
- Refuse to fabricate a recommendation when no candidate clears the declared evidence policy; return `NO_EVIDENCE_ELIGIBLE_ROUTE` with per-candidate evidence instead.
- Rank eligible candidates lexicographically by stronger conservative success evidence, lower conservative overrun risk, lower observed actual WLU, then lower declared expected WLU. Exact ties preserve caller order.
- Preserve raw statistics, Wilson bounds, sample sufficiency, policy-rejection reasons, verified snapshot sequence/tag and the complete candidate assessment set in the advisory result.
- Keep advisory strictly non-entitling: it accepts no WLU authority object and cannot reserve/spend WLU, acquire hierarchy/throughput capacity, promote standby work or invoke a provider.
- Extend Alchemy Objects v0.5 STANDARD adoption and surface-contract coverage to `WLUJobRouteAdvisor`.
- Add `test_route_advisory.rex` and `examples/evidence_weighted_route_advice.rex`.

## v0.10

- Add `WLURouteAnalytics.cls`, a read-only cross-job statistics layer over verified durable route evidence.
- Add `WLUJobRouteAnalytics~verifiedSnapshot()` so a journal is authenticated once and a stable immutable evidence cut can feed multiple reports without repeated MAC verification or moving-tail ambiguity.
- Add stage statistics scoped by exact observation window, optional explicit job-id cohort, stage id and caller-declared minimum sample threshold.
- Preserve raw sample/job counts, settled/released counts, application-declared outcome counts, actual/known-handoff WLU totals and averages, and over-expected counts.
- Add observed basis-point rates plus 95% Wilson score intervals for application-declared `SUCCESS` and over-expected proportions.
- Add transition statistics retaining exact fallback counts and opaque application reason-code counts without inferring quality or causal truth.
- Make insufficient evidence visible rather than unavailable: reports remain readable while `sufficientSample` is false until the declared threshold is met. Default threshold is 30 samples.
- Refuse to mint a new analytics snapshot from a journal whose authenticated chain no longer verifies; an already verified snapshot remains an immutable historical evidence cut.
- Extend Alchemy Objects v0.5 STANDARD adoption and surface-contract coverage to `WLUJobRouteAnalytics`.
- Add `test_route_analytics.rex` and `examples/route_statistics_report.rex`.

## v0.9

- Add `WLURouteJournal.cls`, a durable append-only SipHash-authenticated route-evidence archive separate from the accounting ledger.
- Verify both the original `WLUJobRouteEvidence` proof and a second archive chain proof on every replay.
- Add idempotent `(jobId, routeRevision)` archival, conflict detection, per-job route-order checks, full-chain recovery, durable `history()` and `summary()` views.
- Add `WLUJobBudgetManager~archiveRouteHistory()` as an explicit non-entitling archival boundary; archival/replay changes no WLU budget, account reservation, hierarchy hold or throughput allocation.
- Support archive key rotation by retaining algorithm/key ids for both event proofs and chain proofs.
- Refactor `WLUJobRouteSummary~fromEvents()` so process-resident and durable summaries use the same derivation logic.
- Extend Alchemy Objects v0.5 adoption coverage to `WLUJobRouteFileJournal`.
- Add `test_route_journal.rex`, `test_route_journal_rotation.rex` and `examples/durable_route_replay.rex`.

## v0.8

- Add an authenticated runtime route-evidence stream for logical jobs, separate from hard entitlement, forecasts and standby intent.
- Add `recordTransition()` for application-declared movement along sealed fallback edges; WLU authenticates reason codes/evidence references without judging conversation quality or provider policy.
- Add optional idempotency keys for route decisions so retry does not duplicate evidence.
- Automatically record authenticated `STAGE_RESERVED`, `STAGE_SETTLED` and `STAGE_RELEASED` route events with admission-time forecast generation, standby lineage and pinned rate-card generation.
- Add `settleStageBreakdown()` to preserve actual backend-work versus handoff/rehydration WLU while settling the same total WLU into the logical job and hierarchy.
- Add `routeHistory()` and `routeSummary()` derived evidence surfaces.
- Fix logical-job stage-reservation replay so a core idempotent reservation cannot double-increment parent `committedMicroWlu` or duplicate route evidence.
- Extend hierarchical settlement and provider-plan tests to exercise route/handoff evidence and pinned valuation lineage.
- Add `test_route_execution_evidence.rex` and `examples/route_execution_feedback.rex`.

## v0.7

- Adopt `alchemy_objects_v0.5` and qualify long-lived WLU behavioural objects through `AlchemyAdoptionVerifier`; `WLUAuthority` also passes `SECURE_READY` on r13196.
- Add the v0.5 STANDARD metadata set and reserved-base inheritance-integrity coverage.
- Add `WLUExternalPlan.cls`, a provider-neutral narrow-plan import boundary compatible with Runtime Registry `AbilityWLUPlan` / `AbilityMeterFact` without adding a Runtime Registry/provider dependency.
- Re-value external facts under WLU-owned rate-card policy and fail closed when a planner ceiling is below the authoritative quote.
- Add `WLUImportedStagePlan` retaining TTL/request id, fact count and valuation generation.
- Extend `WLUJobStage` with optional pinned rate-card id/version; hand-authored stages remain compatible through `DIRECT/1` defaults.
- Preserve pinned rate-card generation through hard stage reservation and standby promotion.
- Add same-session Gemma/Grok/OpenAI-style external-plan acceptance and a real `runtime_registry_v0.12` `AbilityWLUPlan` qualification probe.

## v0.6

- Add authenticated non-entitling standby/rescue intents for declared logical-job stages.
- Standby claims bind stage WLU ceiling, WLU/s delivery demand, expiry, advisory priority and lifecycle state while reserving zero account WLU, zero hierarchy WLU and zero throughput.
- Add live standby assessment against current hard job budget and runtime/provider capacity; the hierarchical bridge additionally assesses every enterprise ancestor.
- Add explicit standby promotion to ordinary hard child reservations, preserving make-before-break escalation semantics.
- A failed promotion leaves the standby active for scale/throttle/retry rather than consuming or losing the rescue plan.
- Add direct and hierarchy-backed standby promotion paths, idempotent standby creation, expiry handling, tamper/stale rejection and promoted reservation binding.
- Add `WLUHierarchyBudgetManager~rollbackHold()` for unpublished subtransaction aborts. This removes both temporary hierarchy commitment and its internal idempotency marker, fixing retry-after-core-failure replay of a released hold.
- Harden standby promotion so a standby can only be marked promoted by an active child reservation for the same declared stage.
- Add `test_contingency_standby.rex`, `test_contingency_standby_direct.rex` and `examples/shannon_standby_rescue.rex`.

## v0.5

- Add authenticated live forecast revisions for logical jobs without changing hard entitlement or WLU admission semantics.
- Separate the initial job estimate, hard budget, actual spend/commitment and latest projected expected/upper totals on the authenticated `WLUJobLease`.
- Add `WLUJobForecastRevision` with observation tick, estimator source/reason, declared confidence basis points, trend and expected/upper budget shortfalls.
- Add forecast statuses `WITHIN_BUDGET`, `AT_RISK` and `EXPECTED_OVER_BUDGET`; forecasts that exceed budget are retained as warning evidence rather than rejected.
- Add immutable authenticated forecast history and stale-lease protection after forecast mutation.
- Expose forecast read/revision through `WLUHierarchicalJobManager` without consuming hierarchy budget.
- Add `test_live_forecast.rex`, hierarchy-bridge forecast coverage and `examples/live_job_forecast.rex`.

## v0.4

- Adopt `alchemy_objects_v0.4.3` as the base for long-lived WLU authorities/managers and the authenticated file ledger.
- Add inherited object identity, surface/method contracts, lifecycle/telemetry, requirement declarations, relationship evidence, disclosure-labelled state and capability-gated sealed introspection.
- Keep facts, quotes, reservations, leases, proofs and other high-frequency value carriers lightweight rather than forcing every record through the base class.
- Use `AlchemyObject.cls` directly so Inspector Clouseau is not an implicit hot-path dependency.
- Add `test_alchemy_object_integration.rex` covering sealed public/customer introspection, resource relationships, hierarchy/job manager inheritance and durable-ledger state evidence.
- Add explicit `alchemy_objects_v0.4.3` runtime/test dependency; standalone `oorexx_crypto_v0.1` remains authoritative.

## v0.3

- Adds hierarchical workload-budget constraints (`WLUHierarchy.cls`) for enterprise -> tenant -> service -> job delegation.
- Keeps WLU non-additive across hierarchy levels: one piece of work is checked/reflected at each ancestor but remains one piece of work.
- Child budgets are ceilings, not pre-spent allocations; sibling ceilings may overcommit nominally while live holds remain atomically bounded by every ancestor.
- Adds authenticated budget-node leases and authenticated holds with idempotency, top-up, settlement/release and stale/tamper rejection.
- Adds ancestor-limiter assessment so a child with local headroom can report which upstream budget actually blocks admission.
- Adds `WLUHierarchicalJobManager`, binding logical backend-stage admission to hierarchy holds with rollback when core/provider admission or top-up fails.
- Adds FlyLo/Shannon hierarchical and hierarchical-job acceptance tests, including fail-before-core-reservation behaviour.

## v0.2.1

- Removes the vendored `src/crypto.cls`; WLU now depends explicitly on standalone `oorexx_crypto_v0.1`.
- Removes the private SipHash-2-4-128 implementation from `WLUFastMac.cls`; `WLUSipHash128` is now a compatibility subclass of the shared `.SipHash128`.
- Preserves WLU proof/key-ring wire semantics, SipHash algorithm id, authenticated ledger checkpoints and all v0.2 workload/budget behaviour.
- Test runner requires `CRYPTO_SRC`/`OOREXX_CRYPTO_SRC`, preventing accidental fallback to a stale local crypto copy.


## v0.2

- Added logical-job budgeting: one business job/session can span several execution implementations without minting a new budget per backend call.
- Added sealed fallback execution graphs (`WLUJobPlan` / `WLUJobStage`).
- Added explicit handoff/rehydration workload allowance for history replay and state migration.
- Added authenticated parent `WLUJobLease` with spent, committed and remaining WLU.
- Added strategy coverage (`FULL_STRATEGY` / `PARTIAL_STRATEGY`) against the maximum declared fallback path.
- Added side-effect-free fallback viability assessment against both remaining parent budget and live WLU authority capacity.
- Added make-before-break stage admission so replacement execution can be reserved before an old path is released.
- Added authoritative consumed-WLU query so releasing a child stage preserves already-incurred work in the parent budget.
- Added FlyLo/Shannon script -> Gemma -> Grok/OpenAI escalation acceptance case.

## v0.1

Initial Work Load Units framework.

- Stable integer micro-WLU representation.
- Consumer metering facts and sealed/versioned WLU rate cards.
- Entitlement accounts separate from currency.
- Refillable WLU token/burst capacity buckets with retry-after calculation.
- Work demand model with expected WLU, admitted ceiling and requested WLU/s delivery capacity.
- Reservable WLU/s throughput pools for enterprise scheduling and acceleration.
- Structured, side-effect-free demand assessment.
- Policy-owned account, bucket, throughput and rate-card bindings.
- Atomic admission across all mandatory constraints.
- Idempotent reservations and consumption operations.
- Progressive consumption, top-up, expiry, settlement and release.
- Live delivery-rate reshaping for acceleration/throttling without changing work WLU.
- Fast internal SipHash-2-4-128 reservation authentication.
- Authenticated chained durable ledger.
- Optional Ed25519 ledger checkpoints at export/trust boundaries.
- Optional downstream financial/reporting adapter kept outside the WLU core.
- TN5250 fail-before-side-effect consumer acceptance case.
- Enterprise scale-out/throttle/accelerate acceptance case.
