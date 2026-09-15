# Brand Intervention Governance v0.2

Brand Intervention Governance converts time-scoped, multi-outcome `brand_intervention_effectiveness_v0.2` evidence into bounded review dispositions while preserving the complete reasoning packet for a reasoning model or named external authority.

v0.2 adds an explicit boundary to `institutional_policy_v0.6`: **Brand Intervention Governance owns the domain meaning of its rule set; Institutional Policy owns which reviewed/versioned rule-set artefact is actually operative.**

It remains **non-executing**. It cannot change prompts, treatment, rollout percentages, customer journeys, or sales behaviour.

## v0.2 policy-selection rule

v0.1 would silently construct a local `BRAND-GOVERNANCE-V1` rule set when the caller supplied no rules. That made deterministic testing convenient but blurred an important authority boundary: a component-local default could look indistinguishable from an institutionally selected operative policy.

v0.2 removes that ambiguity.

### Managed/operative path

Resolve an exact policy through the Institutional Policy catalogue:

```text
InstitutionalPolicyCatalog
        |
        | resolve / resolveForContext
        v
InstitutionalPolicyExecutionContext
        |
        v
BrandInterventionGovernancePolicySelection
        |
        | exact policy id/version/semantic identity
        | resolution time and mode
        | deployment/topology identity
        | publication assurance + authority record
        | exact BrandInterventionGovernanceRuleSet payload
        v
BrandInterventionGovernanceEngine~recommendUnderInstitutionalPolicy(...)
```

`BrandInterventionGovernancePolicySelection` preserves the exact externally resolved Institutional Policy evidence. It does **not** reimplement publication, suspension, withdrawal, topology, progressive rollout, succession, delegation, emergency publication, or authority semantics.

If Institutional Policy says a release is not effective, suspended, withdrawn, staged, not deployed, ambiguous, or otherwise non-operative, selection fails with that explicit resolution code.

### Explicit low-level path

`BrandInterventionGovernanceEngine~recommend(binding, rules)` remains available for tests, counterfactual reasoning and callers that intentionally manage policy outside this package. The rule set must now be supplied explicitly and sealed.

There is **no implicit default**. Calling `recommend(binding)` returns:

```text
GOVERNANCE_RULE_SET_REQUIRED
```

Recommendations created from explicit low-level rules are marked:

```text
INSTITUTIONAL_POLICY_MANAGED=0
EXPLICIT_UNMANAGED_RULE_SET
INSTITUTIONAL_POLICY_SELECTION_REQUIRED_FOR_OPERATIVE_USE
```

A positive exposure decision (`APPROVE_CONTROLLED_PILOT`, `APPROVE_LIMITED_EXPANSION`, or `CONTINUE_CURRENT`) cannot be sealed from an unmanaged recommendation. Non-expanding records such as `NO_CHANGE`, evidence collection, pause, or withdrawal remain recordable; this package still does not execute them.

## Core rules

- Association remains `ASSOCIATION_ONLY`, including when study-design provenance says `RANDOMIZED`.
- A recommendation always requires named external authority before an operational change.
- Positive exposure decisions additionally require an exact operative Institutional Policy selection.
- Guardrails remain distinct outcomes; there is deliberately no scalar utility/fitness score.
- Mixed primary/guardrail evidence becomes withdrawal/review, not a successful optimisation result.
- Stale evidence cannot change exposure.
- Current-window regression is not averaged away into a long baseline.
- A controlled exposure cap is a review ceiling, not permission to assign customers.
- Counterevidence, denominators, classifier/taxonomy provenance, confidence gates, time windows and release provenance remain in the upstream reasoning material.
- Service-as-Sales / brand significance does not confer sales authority.
- Institutional Policy selection does not confer execution authority.
- Divergent authority decisions remain possible but must cite an opaque evidence point; free prose cannot hide customer data in that field.

## Dispositions

`MEASURE_MORE`, `HOLD_BASELINE`, `REVIEW_REQUIRED`, `CONTROLLED_PILOT_REVIEW`, `CONTROLLED_EXPANSION_REVIEW`, `CONTINUE_CURRENT_REVIEW`, `WITHDRAWAL_REVIEW`, and `REGRESSION_REVIEW` are **review dispositions only**.

The package records a later named-authority decision separately and still marks execution as external.

## Current compatibility baseline

Validated with:

```text
Open Object Rexx 5.3.0 r13196 Internal Test Version
Alchemy Objects v0.8
ooRexx Crypto v0.1
Brand Interaction Effect v0.6
Brand Journey v0.1
Brand Journey Population v0.2
Brand Intervention v0.2
Brand Intervention Effectiveness v0.2
Institutional Policy v0.6
Runtime Registry v0.14
```
