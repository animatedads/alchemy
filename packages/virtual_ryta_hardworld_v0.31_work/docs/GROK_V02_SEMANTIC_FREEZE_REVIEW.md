# Grok Review Request — HardWorld / Virtual RYTA v0.2 Semantic Freeze

## Role

You are reviewing an executable deterministic safety/decision substrate, not an LLM prompt and not an airline product specification.

Your task is adversarial: identify semantic holes that could allow two competent implementations to produce different outcomes, an approval to escape its intended scope, a score to leak into authority, an UNKNOWN/CONFLICT fact to collapse, or an incomplete rule domain to appear complete.

## What changed following your v0.1 review

Your review identified three highest-risk issues:

1. numeric priority;
2. `SUPPRESSED` versus `PROHIBITED`;
3. approval scope/model/world binding.

v0.2 implements the following decisions.

### A. Numeric priority removed from rule definition

Executable rules now use:

```text
SAFETY_CRITICAL
SAFETY_NORMAL
OPERATIONAL
COMMERCIAL
```

Numeric rank exists only as private implementation mapping.

`OVERRIDES` is restricted to **same-tier** collision resolution.

The current conflict and unknown rules are both `SAFETY_CRITICAL`, with:

```text
RYTA-CRITICAL-CONFLICT
    OVERRIDES RYTA-CRITICAL-UNKNOWN
```

Removing that edge is an executable mutation and causes a `RULE_CONFLICT` on overlapping vectors.

### B. `SUPPRESSED` retained with a narrow formal meaning

```text
SUPPRESSED:
    action is intrinsically permissible,
    but must not be offered/elected in this decision context.
```

It carries `CONTEXTUAL` metadata.

It differs from:

```text
PROHIBITED:
    action is ineligible in this decision context;
    v0.2 default is NON_OVERRIDEABLE.
```

A test demonstrates that `SELL_PRODUCT` is SUPPRESSED during remediation but becomes PERMITTED and selectable when the world returns to NORMAL, without an approval or override.

### C. Approval binding hardened

Approval validation requires exact binding to:

```text
approval id
authority
action
model id
model version
world snapshot OID
scope
expiry
revocation state
APPROVE/DENY decision
quorum of unique approval ids
```

Wildcard scope is deliberately rejected in v0.2.

Conflicting APPROVE/DENY receipts reject the gate.

Duplicate ids do not inflate quorum.

### D. Capability separated from obligation

Every action has a `CAN_<ACTION>` fact.

A REQUIRED action with capability false/unknown/conflict remains REQUIRED but unsatisfied. Execution status becomes:

```text
REQUIRED_ACTION_UNAVAILABLE
```

and escalation becomes REQUIRED.

### E. Joint requirement conflict added

A `MUTUALLY_EXCLUSIVE` action constraint can detect two individually REQUIRED actions that cannot jointly execute.

The engine produces:

```text
CONFLICTING_REQUIREMENTS
```

blocks arbitrary choice, leaves both requirements unsatisfied, and requires escalation.

### F. No implicit action permission fallback

Every reachable state/action pair has an explicit policy row.

Deleting one creates `ACTION_DISPOSITION_HOLE` coverage.

### G. Coverage and mutation

Current clean reference report:

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

Mutation suite:

```text
M1–M16 killed = 16
survivors = 0
```

Adversarial corpus:

```text
25/25 pass
```

## Current executable language

Conditions allow only:

```text
ALL
ANY

KNOWN_TRUE
KNOWN_FALSE
UNKNOWN
CONFLICT
```

Banned in executable v0.2:

```text
AND OR NOT XOR IMPLIES ELSE DEFAULT UNLESS EXCEPT
SHOULD SHOULD_NOT
MIGHT COULD
```

`CAN/CANNOT` are capability-fact vocabulary only, never permission operators.

## Questions for your v0.2 review

Please do not simply endorse the design. Try to break it.

1. Is the same-tier-only `OVERRIDES` rule sufficient and less ambiguous than allowing cross-tier override edges?
2. Is the v0.2 definition of `SUPPRESSED` mechanically distinguishable enough from `PROHIBITED` to retain it?
3. Can exact approval scope introduce legitimate operational cases that require an explicit scope hierarchy rather than wildcard matching? If so, propose a machine-checkable hierarchy that cannot accidentally widen authority.
4. Is `REQUIRED_ACTION_UNAVAILABLE` correctly modelled as execution status while retaining the original world-derived decision state?
5. Is blocking both mutually exclusive REQUIRED actions and escalating the correct fail-closed behaviour, or is another representation of unsatisfied obligations needed?
6. What additional static rule checks should exist before model execution?
7. Which of the C1–C16 coverage classes are underspecified or conflated?
8. Propose at least 20 new mutants not equivalent to M1–M16.
9. Propose at least 25 new adversarial cases that target interactions between tiering, capability, approval, epistemic state and joint constraints.
10. Identify any place where a model author can still hide a default, widen an approval, or encode a hard rule as a score.

## Required answer format

Return:

```text
A. EXECUTIVE FINDING
B. BLOCKERS
C. SEMANTIC AMBIGUITIES
D. APPROVAL / AUTHORITY ATTACKS
E. CAPABILITY / OBLIGATION ATTACKS
F. TIER / OVERRIDES ATTACKS
G. SUPPRESSED / PROHIBITED FINDING
H. COVERAGE TAXONOMY CHANGES
I. NEW MUTATION CATALOGUE (20+)
J. NEW ADVERSARIAL CORPUS (25+)
K. RECOMMENDED v0.3 CHANGES
L. PRODUCTION-LANGUAGE GO / NO-GO
```

For every criticism, give at least one concrete counterexample world/rule/action tuple where possible.

Do not introduce an LLM, natural-language policy parser, or probabilistic interpretation as the solution. This review is about deterministic rule semantics and authority boundaries.
