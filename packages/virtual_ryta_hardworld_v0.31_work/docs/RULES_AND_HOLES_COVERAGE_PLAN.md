# HardWorld Rules-and-Holes Coverage Plan v0.2

## Goal

Coverage means that the declared decision domain has machine evidence for completeness and consistency. Source-line coverage is not sufficient.

The current reference domain has three four-state facts:

```text
4 × 4 × 4 = 64 core world vectors
```

All 64 are executed exhaustively.

## C1–C16 coverage taxonomy

| Code | Class | Meaning |
|---|---|---|
| C1 | `INPUT_HOLE` | reachable input vector has no resolvable state |
| C2 | `RULE_OVERLAP` | more than one rule matches; not automatically an error |
| C3 | `CONFLICTING_WINNER` | highest-tier surviving rules disagree |
| C4 | `SHADOWED_RULE` | rule matches but never wins |
| C5 | `UNREACHABLE_RULE` | rule never matches declared domain |
| C6 | `ACTION_DISPOSITION_HOLE` | reachable state/action pair lacks explicit policy |
| C7 | `TRANSITION_HOLE` | observed state differs from reference contract / missing transition |
| C8 | `ILLEGAL_EFFECT_COMBINATION` | jointly impossible hard effects, including mutually exclusive requirements |
| C9 | `APPROVAL_POLICY_HOLE` | approval-gated effect lacks complete approval policy |
| C10 | `OVERRIDE_POLICY_HOLE` | invalid tier/override/overrideability semantics |
| C11 | `EPISTEMIC_COLLAPSE` | UNKNOWN/CONFLICT or invalid predicate is collapsed/misread |
| C12 | `DEFAULT_FALLTHROUGH` | undeclared default or banned structural operator hides a vector |
| C13 | `MODEL_VERSION_HOLE` | decision/approval does not bind exact model version |
| C14 | `PROVENANCE_HOLE` | decision lacks world/model/source identity required for replay/audit |
| C15 | `REQUIRED_CAPABILITY_HOLE` | required action is impossible/unknown/conflicted without unsatisfied-requirement handling |
| C16 | `SCORE_LEAK_INVARIANCE` | score influences REQUIRED/PROHIBITED eligibility |

C2 is primarily informational. An overlap becomes C3 only when the surviving highest-tier rules disagree and no explicit same-tier `OVERRIDES` edge resolves it.

## Static/model checks

The v0.2 analyser checks:

```text
valid named tiers
valid ALL/ANY combinators
valid explicit epistemic predicates
OVERRIDES target exists
OVERRIDES is same-tier only
explicit state/action policy matrix
valid dispositions
SUPPRESSED carries CONTEXTUAL semantics
PROHIBITED remains NON_OVERRIDEABLE
approval-gated policy has policy id
unreachable rules
shadowed rules
```

## Dynamic checks

The suite checks:

```text
64/64 core epistemic vectors
reference state for every vector
UNKNOWN != FALSE
CONFLICT != UNKNOWN
same-tier collision behaviour
score invariance
approval binding
expiry/revocation
approval conflict
quorum and duplicate receipts
required-but-incapable action
mutually exclusive REQUIRED actions
SUPPRESSED vs PROHIBITED distinction
```

## Current clean-model report

Expected v0.2 summary:

```text
vectors=64
holes=0
ambiguous=0
overlaps=36
expected_mismatches=0
disposition_holes=0
language_issues=0
unreachable=0
shadowed=0
issues=0
```

The 36 raw overlaps are retained intentionally as evidence that precedence is doing work rather than being hidden.

## Relational report shape

`RYTACoverageReport~relationLines` emits:

```text
coverage_dimension
vector_id
essential
immediate
custody
match_count
highest_tier
winner_rule
result_state
expected_state
hole
ambiguous
expected_match
```

This is the first direct preparation for a future NoSQLServer `AlgorithmRelation` adapter.

## M1–M16 mutation catalogue

| Mutation | Required detector |
|---|---|
| M1 TRUE/FALSE safety predicate swap | expected-state mismatch |
| M2 UNKNOWN→FALSE | epistemic/state mismatch or ambiguity |
| M3 CONFLICT→UNKNOWN | epistemic/state mismatch |
| M4 ALL→ANY | state matrix mismatch |
| M5 REQUIRED→PERMITTED | required-action contract fails |
| M6 PROHIBITED→PERMITTED | hard-score invariant fails |
| M7 remove safety clause | matrix mismatch |
| M8 remove safety rule | input hole/mismatch |
| M9 remove explicit OVERRIDES | conflicting winner |
| M10 remove approval requirement | unapproved action executes |
| M11 widen approval scope | cross-context approval would execute |
| M12 make prohibition effectively overrideable | approval defeats prohibition |
| M13 change safety state target | matrix mismatch |
| M14 allow score into hard eligibility | C16 failure |
| M15 accept stale model/world approval | approval-binding failure |
| M16 treat capability failure as satisfied | C15 failure |

`tests/test_ryta_mutation_guards.rex` currently reports:

```text
killed: 16
survivors: 0
```

## Deployment posture

For safety-critical finite rule groups:

```text
C1/C3/C6/C8/C9/C10/C11/C12/C13/C14/C15/C16 -> deployment blocker
mutation survivors -> deployment blocker
```

Raw C2 overlaps may be accepted only when the winning semantics are explicit and covered.
