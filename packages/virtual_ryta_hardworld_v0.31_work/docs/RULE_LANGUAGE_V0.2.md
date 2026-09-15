# HardWorld Rule Language v0.2 — Semantic Freeze Candidate

Status: **executable semantic freeze candidate** for the Virtual RYTA testbed.

The rule language is intentionally smaller than ordinary Boolean logic or natural-language policy. The design goal is not expressive elegance. The goal is that every executable term has one inspectable machine meaning and that finite rule domains can be exhaustively checked for holes, overlaps and contradictions.

## 1. Normative meanings

| Term family | v0.2 machine class | Meaning |
|---|---|---|
| `MUST`, `REQUIRED`, `REQUIRE` | hard obligation | the action/effect remains required regardless of preference score; execution still requires capability |
| `MUST_NOT`, `PROHIBITED`, `PROHIBIT` | hard prohibition | the action is ineligible; score and approval are irrelevant |
| `MAY`, `PERMITTED`, `PERMIT` | permission | the action is not prohibited; preference may elect it |
| `CAN`, `CANNOT` | capability fact only | describes capability/possibility, never authority or permission |
| `SHOULD`, `SHOULD_NOT` | banned in executable v0.2 | soft recommendation requires a future explicit deviation model |
| `MIGHT`, `COULD` | banned in executable v0.2 | uncertainty must be represented by explicit facts/epistemic state |

`HardWorldLanguageSpec` exposes these classifications directly.

## 2. Epistemic predicates

A critical fact is tested only by one of:

```text
KNOWN_TRUE
KNOWN_FALSE
UNKNOWN
CONFLICT
```

There is no direct four-valued `AND`, `OR` or `NOT` in v0.2.

`UNKNOWN` means no accepted value is available.

`CONFLICT` means incompatible accepted claims exist.

Neither is coerced to false.

## 3. Combinators

Only:

```text
ALL { ... }
ANY { ... }
```

are executable rule combinators.

The following are rejected/banned structural forms in v0.2:

```text
AND
OR
NOT
XOR
IMPLIES
ELSE
DEFAULT
UNLESS
EXCEPT
```

This deliberately removes precedence ambiguity and hidden fall-through.

## 4. Named rule tiers

Executable state rules use one of:

```text
SAFETY_CRITICAL
SAFETY_NORMAL
OPERATIONAL
COMMERCIAL
```

The evaluator considers all matching rules, selects the highest non-empty tier, then resolves only that tier.

Numeric ranks exist only as an internal implementation mapping. Rule definitions do not expose numeric priority.

## 5. `OVERRIDES`

`OVERRIDES <rule_id>` is **same-tier only** in v0.2.

It exists solely to resolve an explicitly understood collision between matching rules at the same tier.

Example:

```text
RYTA-CRITICAL-CONFLICT
    TIER SAFETY_CRITICAL
    OVERRIDES RYTA-CRITICAL-UNKNOWN
```

Both rules can match the same world vector. The override edge declares why the conflict rule survives.

Cross-tier `OVERRIDES` is invalid because tier ordering already decides cross-tier precedence.

If multiple surviving highest-tier rules lead to the same state, the overlap is compatible and remains visible in coverage.

If surviving highest-tier rules lead to different states and no explicit override resolves them:

```text
state = RULE_CONFLICT
ambiguous = TRUE
```

The model fails closed and requires escalation.

## 6. Action dispositions

Every reachable `state × action` pair has an explicit policy row. There is no implicit default-permit policy.

### `REQUIRED`

The action is normatively required. Score is ignored.

If `CAN_<ACTION>` is not `KNOWN_TRUE`, the requirement remains unsatisfied and execution status becomes:

```text
REQUIRED_ACTION_UNAVAILABLE
```

Escalation becomes required.

### `PERMITTED`

Preference score may elect the action. Capability is still required to execute it.

### `SUPPRESSED`

Formal v0.2 definition:

> The action is intrinsically permissible but is intentionally not offered/elected in the current decision context.

A suppressed action does not execute even with a positive score.

`SUPPRESSED` is **not** a hard prohibition. The same action may become `PERMITTED` when the contextual state changes without an override or approval.

Every `SUPPRESSED` policy must carry:

```text
OVERRIDE_CONTEXTUAL
```

in the model metadata so auditors cannot collapse it accidentally into `PROHIBITED`.

### `PROHIBITED`

The action is ineligible. Score is irrelevant.

In v0.2 it is:

```text
NON_OVERRIDEABLE
```

by default and approvals cannot alter it.

### `REQUIRES_APPROVAL <policy>`

Preference must first elect the action. Capability must be present. A matching approval policy must then validate.

This is an approval gate on an otherwise eligible action, not an override of prohibition.

## 7. Capability

Capability is represented as ordinary world facts:

```text
CAN_ANSWER_QUERY
CAN_SELL_PRODUCT
CAN_WARNING
CAN_UPSELL
CAN_BIG_UPSELL
CAN_ASK_INFORMATION
CAN_ESCALATE
```

They use the same epistemic model.

`CAN_WARNING = FALSE` never means `WARNING` is no longer required.

It means:

```text
WARNING = REQUIRED
requirement_satisfied = FALSE
execution_status = REQUIRED_ACTION_UNAVAILABLE
ESCALATE = REQUIRED
```

The Virtual RYTA testbed supplies `KNOWN_TRUE` capability defaults only for absent capability facts to keep the test actor concise. Production adapters are expected to provide real capability facts explicitly.

## 8. Approval binding

An approval is valid only when all of the following match:

```text
approval_id       unique receipt identity
authority         authority required by approval policy
action_code       exact action
model_id          exact model
model_version     exact model version
world_snapshot_oid exact frozen input world
scope             exact decision scope
expiry            not expired
revoked           false
decision          APPROVE
quorum            satisfied by unique approval ids
```

Wildcard/cross-context approval scope is not accepted by v0.2.

A `DENY` and `APPROVE` applying to the same gate produces:

```text
CONFLICTING_APPROVALS
```

and does not authorise execution.

Duplicate approval IDs do not count twice toward quorum.

## 9. Mutually exclusive hard requirements

The framework includes `RYTAActionConstraint`.

For a `MUTUALLY_EXCLUSIVE` constraint, if both actions become `REQUIRED` simultaneously:

```text
execution_status = CONFLICTING_REQUIREMENTS
both constrained actions final_selected = FALSE
both requirements remain unsatisfied
ESCALATE = REQUIRED
```

The engine must not arbitrarily pick one requirement and pretend the rule model was coherent.

## 10. Current reference state rules

Core facts:

```text
ESSENTIAL_MEDICATION
IMMEDIATE_ACCESS
GUARANTEED_CUSTODY
```

State contract:

```text
if any critical fact is CONFLICT
    -> ESCALATE
else if any critical fact is UNKNOWN
    -> NEEDS_INFORMATION
else if ESSENTIAL_MEDICATION is KNOWN_FALSE
     or IMMEDIATE_ACCESS is KNOWN_FALSE
    -> NORMAL
else if GUARANTEED_CUSTODY is KNOWN_FALSE
    -> REMEDIATION_REQUIRED
else
    -> NORMAL
```

The final `else` above is descriptive documentation only. The executable model contains an explicit safe-custody rule; deleting it creates a coverage hole.

## 11. Required invariants

```text
BIG_UPSELL score +1,000,000 + PROHIBITED
    -> never executes

WARNING score -1,000,000 + REQUIRED + capability TRUE
    -> executes

WARNING REQUIRED + capability FALSE
    -> does not execute
    -> requirement remains unsatisfied
    -> escalation required

approval for wrong model/version/world/action/scope
    -> invalid

same-tier incompatible state rules without OVERRIDES
    -> RULE_CONFLICT
```

## 12. Explicitly deferred

Not part of v0.2 executable semantics:

```text
raw four-valued Boolean operators
SHOULD / deviation policies
temporal validity intervals on facts
cryptographic approval receipts
approval delegation chains
hierarchical/concurrent state machines
natural-language policy parsing
LLM interpretation
NoSQLServer AlgorithmRelation adapter
```

Those features must extend coverage obligations before becoming executable.
