# Institutional Policy v0.8

Institutional Policy is the shared deployment/governance substrate for fixed, reviewable, versioned business policy artefacts. Domain modules retain their own semantics; this component owns publication identity, authority, effective time, lifecycle, topology, progressive rollout, replay and rollout-evidence gates.

## v0.8: post-promotion rollback evidence

Progressive rollout may now carry a second fixed gate for the period after cutover. Promotion criteria answer whether the successor may be widened; rollback criteria answer whether observed degradation makes an automatic return to the exact prior reviewed artefact eligible.

`InstitutionalPolicyRollbackGate` uses sealed criteria and an explicit `ANY` or `ALL` trigger mode. `InstitutionalPolicyRollbackEvaluator` records immutable `ROLLBACK_ELIGIBLE`, `ROLLBACK_NOT_REQUIRED`, or `ROLLBACK_INSUFFICIENT_EVIDENCE` assessments. `applyAutomatedRollback` re-evaluates the supplied observations internally and therefore does not trust a caller-supplied assessment object.

Automatic rollback is not the only rollback mechanism. Ordinary authorized deployment of the prior policy remains available for incidents that fixed metrics did not anticipate. Promotion/rollback observations are deployment-governance evidence and never customer or domain evidence. Evidence freshness is measured from the observation's own `recordedAt`, preventing old metrics from being made fresh by delayed re-evaluation.

## Fixed-artifact invariant

An operative artefact must declare `FIXED_REVIEWABLE_VERSIONED_ARTIFACT`. Runtime LLM generation is not an operative policy mechanism. LLMs or people may author a candidate policy, but production operates the sealed reviewed artefact.

## v0.7: evidence-gated progressive promotion

A progressive rollout may now embed a sealed `InstitutionalPolicyRolloutGate`. The gate is part of the exact authorized rollout identity; it cannot be swapped after rollout authorization.

The gate contains deterministic numeric criteria such as:

```text
EVALUATED_ACTIONS          GE 1000   minimum sample 1000
FALSE_POSITIVE_RATE        LE 0.01   minimum sample 1000
SEVERE_SECURITY_INCIDENTS EQ 0      minimum sample 1000
```

It can also require a minimum evidence-window duration and a maximum age for evidence used to schedule promotion. Supported numeric comparators are `GE`, `GT`, `LE`, `LT`, `EQ`, and `NE`.

The host supplies sealed `InstitutionalPolicyRolloutObservation` objects. Each observation is bound to the exact rollout id, policy id, successor version and semantic identity, and records metric name/value, sample size, evidence window, source, evidence reference, optional deployment scope and record time.

`InstitutionalPolicyRolloutEvaluator` deterministically produces one of:

- `PROMOTION_ELIGIBLE`
- `PROMOTION_BLOCKED`
- `INSUFFICIENT_EVIDENCE`

A failed criterion dominates an insufficient criterion: known bad evidence is not softened into “not enough data”. Missing metrics, undersized samples and undersized time windows remain explicitly insufficient rather than being guessed.

When a progressive rollout contains a gate, an `ACTIVE` deployment of the successor during that rollout is evaluated by the catalogue itself. Callers cannot submit a hand-written PASS object. The resulting assessment is retained as immutable deployment-governance evidence. Failed authorized promotion attempts are retained too.

`CANARY` and `STAGED` bindings do not require promotion evidence; they are how evidence is gathered. Rollback to the exact previously reviewed policy also remains available without requiring proof that the successor is healthy.

Rollout evidence is deliberately separate from domain/customer evidence. A deployment metric such as `FALSE_POSITIVE_RATE=0.025` may block promotion of a Security policy, but it is not a Security finding about any customer.

## Existing institutional mechanics retained

- sealed/versioned policy publication
- author/approver/publisher authority and optional verified approval evidence
- multi-party approval requirements
- effective-dated authority-profile succession
- delegation and transitive revocation
- bounded emergency publication and later ratification
- immutable suspend/resume/withdraw lifecycle evidence
- scoped deployment topology (`service/region/channel/tenant/cohort`)
- bounded progressive overlap of exact reviewed policy versions
- deterministic canary/cutover/rollback routing
- operative vs counterfactual replay
- historical publication and governance evidence preservation

## Evidence trust boundary

The component makes the *interpretation* of rollout observations deterministic and reviewable. It does not claim that an external metric producer is truthful. `sourceId` and `evidenceRef` preserve that provenance so hosts can add attestation, audit-log, database or monitoring-system verification appropriate to their environment.

## Dependencies

- ooRexx 5.3.0 r13196 or compatible
- Alchemy Objects v0.8
- ooRexx Crypto v0.1

Legal Effect v0.14 is exercised as an integration companion.
