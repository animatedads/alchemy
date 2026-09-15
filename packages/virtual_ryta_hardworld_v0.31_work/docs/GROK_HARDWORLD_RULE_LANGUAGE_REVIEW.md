# GROK REVIEW BRIEF — HardWorld Rule Language and Virtual RYTA

**Document status:** review input, not an approved specification  
**Project:** ooRexx SQL Things / Algorithm-as-a-Relation / HardWorld  
**Reference implementation:** Virtual RYTA ooRexx testbed v0.1  
**Primary task for Grok:** attack and improve the language of definition so that machine-executed rules have unambiguous, testable semantics and measurable coverage.

---

## 0. What this is NOT

This is not an LLM prompt-engineering exercise.

The architecture treats an LLM, if one is ever connected, as only one possible algorithmic producer or consumer. The reference implementation contains no LLM.

The target abstraction is:

> **A versioned, schema-bound algorithm consumes typed world-state facts and produces an inspectable relation of decisions, states, effects, approvals and trace evidence.**

Examples elsewhere in the wider project include deterministic camera-behaviour categorisation, deterministic Librarian text categorisation, scoring matrices, and state-machine safety logic.

Virtual RYTA is intentionally stupid. Its job is to make decision semantics visible.

---

## 1. Your mission

Review the proposed semantics below as if a bad interpretation could result in a safety rule, contractual rule, regulatory rule, operational rule or approval rule being executed incorrectly.

Do **not** optimise for natural-language elegance. Optimise for:

1. one machine interpretation;
2. one human-auditable interpretation;
3. explicit treatment of missing and conflicting facts;
4. explicit precedence and conflict resolution;
5. explicit approval authority;
6. exhaustive or measurable rule-space coverage;
7. ability to prove that a numeric preference score cannot override a hard rule;
8. ability to identify holes, overlaps, unreachable rules and accidental fall-through;
9. deterministic replay from the same world snapshot and rule/model version.

Your answer should challenge this document where necessary. Do not merely agree with it.

---

## 2. Architectural separation that MUST survive your review

The testbed deliberately separates four things:

```text
WORLD FACTS
    |
    v
PREFERENCE / SCORING ALGORITHM
    |
    v
PROVISIONAL ACTION ELECTION
    |
    v
HARD STATE / RULE MODEL
    |
    +--> REQUIRED
    +--> PERMITTED
    +--> SUPPRESSED
    +--> PROHIBITED
    +--> REQUIRES_APPROVAL
    |
    v
FINAL ACTION ELIGIBILITY
    |
    v
ACTION METHOD DISPATCH
```

**Invariant A:** a score expresses preference, never authority.

**Invariant B:** `PROHIBITED` remains prohibited even if the action score is +1,000,000.

**Invariant C:** `REQUIRED` remains required even if the action score is -1,000,000.

**Invariant D:** approval is not a score.

**Invariant E:** an approval may satisfy an explicit `REQUIRES_APPROVAL` gate. It does not implicitly negate `PROHIBITED`.

**Invariant F:** state/rule evaluation does not execute action methods. Only the final dispatcher executes action methods.

If you propose any language feature that weakens these separations, call that out explicitly and justify it.

---

## 3. Current Virtual RYTA actor

The test actor exposes observable methods with deliberately trivial outputs:

```text
answerQuery()        -> "blah blah blah answer query"
sellProduct()        -> "sell product"
doWarning()          -> "do warning"
upsellHere()          -> "upsell here"
bigUpsellHere()       -> "big upsell here"
askForInformation()   -> "ask for information"
escalate()            -> "escalate"
```

A deliberately basic scoring plugin currently produces preferences such as:

```text
HAS_QUERY                    => ANSWER_QUERY +10
PRODUCT_RELEVANT             => SELL_PRODUCT +5
CUSTOMER_ELIGIBLE = FALSE    => SELL_PRODUCT -10
UPSELL_OPPORTUNITY           => UPSELL +3
PRODUCT_VALUE_HIGH           => BIG_UPSELL +8
WARNING                      => -2 by default
```

These numbers are not safety semantics. They exist to give the HardWorld model something to constrain.

---

## 4. Current epistemic model

A world fact has a value and an epistemic state.

The current testbed supports:

```text
KNOWN(value)
UNKNOWN
CONFLICT
```

For Boolean facts, this creates the practically relevant four cases:

```text
KNOWN_TRUE
KNOWN_FALSE
UNKNOWN
CONFLICT
```

Important intended meanings:

- `KNOWN_FALSE` means there is an accepted value of false.
- `UNKNOWN` means the system does not have an accepted value.
- `CONFLICT` means accepted inputs disagree or mutually incompatible claims are present.
- `UNKNOWN` and `CONFLICT` MUST NOT silently collapse to false.

### Current design choice to review

The rule engine does **not** currently apply raw four-valued Boolean `AND`, `OR`, and `NOT` directly to facts.

Instead a clause first performs an explicit epistemic predicate:

```text
ESSENTIAL_MEDICATION KNOWN_TRUE
IMMEDIATE_ACCESS KNOWN_TRUE
GUARANTEED_CUSTODY KNOWN_FALSE
```

Each clause match is then ordinary Boolean true/false. `ALL` and `ANY` combine those clause matches.

This avoids silently defining expressions such as:

```text
NOT UNKNOWN
TRUE AND CONFLICT
FALSE OR UNKNOWN
```

before we have deliberately chosen their semantics.

### Grok task EPISTEMIC-1

Assess whether this separation is the safest base model.

If you recommend direct four-valued operators, provide complete truth tables for:

```text
NOT
AND
OR
XOR (if retained)
```

across:

```text
TRUE
FALSE
UNKNOWN
CONFLICT
```

and explain the safety consequence of every non-obvious cell.

If you recommend *not* supporting direct four-valued operators, specify the allowed predicate vocabulary instead.

---

## 5. Proposed normative vocabulary

The project needs a deliberately restricted vocabulary. Natural-language near-synonyms are dangerous in executable rules.

The following semantics are proposed for review.

### 5.1 Hard requirement

```text
MUST
REQUIRED
```

Proposed meaning:

> An objectively testable condition or action that is mandatory for the rule/model to be satisfied. The implementation is non-conforming if it knowingly treats the requirement as optional.

Machine effect candidate:

```text
REQUIRED
```

### 5.2 Hard prohibition

```text
MUST NOT
PROHIBITED
```

Proposed meaning:

> An action or state is not eligible. Preference scores do not alter this result. Approval does not alter it unless the rule explicitly declares a separately modelled override mechanism.

Machine effect candidate:

```text
PROHIBITED
```

### 5.3 Recommendation

```text
SHOULD
RECOMMENDED
SHOULD NOT
NOT_RECOMMENDED
```

Proposed meaning:

> A default recommendation from which deviation can be legitimate only under a declared deviation policy, with a recorded reason.

Open question:

Should `SHOULD` exist in executable HardWorld rules at all?

Possible safer model:

```text
RECOMMENDED action
DEVIATION_POLICY <policy-id>
```

rather than assigning hidden special semantics to `SHOULD`.

### 5.4 Permission

```text
MAY
PERMITTED
```

Proposed meaning:

> The model does not prohibit the action under this rule. Permission does not require execution and does not imply capability.

Machine effect candidate:

```text
PERMITTED
```

### 5.5 Capability / possibility

```text
CAN
CANNOT
```

Proposed meaning:

> `CAN` and `CANNOT` describe capability or possibility, not authority or permission.

Examples:

```text
A bag CAN enter the hold.
```

must not mean:

```text
The system MAY place the bag in the hold.
```

Likewise:

```text
The current system CANNOT guarantee cabin custody.
```

is a fact about capability, not by itself a normative prohibition.

### 5.6 Uncertain possibility

```text
MIGHT
COULD
```

Proposed rule-language policy:

> Do not permit these words in executable normative clauses. Rewrite them into an explicit epistemic or possibility fact.

Examples:

```text
BAD:  the bag might enter the hold
GOOD: HOLD_ENTRY_POSSIBLE = KNOWN_TRUE

BAD:  the customer could require immediate access
GOOD: IMMEDIATE_ACCESS = UNKNOWN
```

### Grok task MODAL-1

For every term above:

1. confirm or reject the proposed semantics;
2. identify dangerous aliases;
3. state whether it is legal in executable rules, comments only, or prohibited entirely;
4. define its exact machine representation;
5. give one adversarial example where a weak parser/human reader would misinterpret it.

Use BCP 14 / RFC 2119 and RFC 8174 as useful requirements-language background, but this project requires its own exact executable semantics rather than assuming that prose conventions are sufficient.

---

## 6. Words and constructs proposed to be banned from executable conditions

Review this proposed ban list:

```text
unless
except
normally
usually
generally
where appropriate
where possible
if necessary
as needed
reasonable
sufficient
adequate
might
could
and/or
```

Reason: each hides a condition, exception, authority decision, threshold or ambiguity that should instead be represented explicitly.

Examples:

```text
BAD:
  big upsell is permitted unless a safety issue exists

BETTER:
  IF SAFETY_STATE = NORMAL
  THEN BIG_UPSELL PERMITTED

  IF SAFETY_STATE = REMEDIATION_REQUIRED
  THEN BIG_UPSELL PROHIBITED
```

### Grok task LEXICAL-1

Expand or reduce the ban list and explain why.

---

## 7. Condition language

Current reference implementation supports rule clauses of the shape:

```text
<fact> <epistemic-predicate>
```

Current predicates:

```text
KNOWN_TRUE
KNOWN_FALSE
UNKNOWN
CONFLICT
```

Current combinators:

```text
ALL   # all clauses must match
ANY   # one or more clauses must match
```

### Proposed future surface syntax

Illustrative only:

```text
RULE RYTA-CUSTODY-UNSAFE
PRIORITY SAFETY_NORMAL
WHEN ALL {
    ESSENTIAL_MEDICATION KNOWN_TRUE
    IMMEDIATE_ACCESS KNOWN_TRUE
    GUARANTEED_CUSTODY KNOWN_FALSE
}
THEN {
    STATE REMEDIATION_REQUIRED
    REQUIRE WARNING
    SUPPRESS SELL_PRODUCT
    PROHIBIT UPSELL
    PROHIBIT BIG_UPSELL
}
```

### Proposed operator restrictions

1. Mixed `AND` and `OR` without explicit grouping is invalid.
2. `and/or` is invalid.
3. Bare `NOT fact` is invalid for epistemic facts because it can conflate false, unknown and conflict.
4. Exceptions are represented as explicit conditions/rules, not `unless` prose.
5. Conditions do not have side effects.
6. State effects do not mutate the input world snapshot.
7. A decision run evaluates one immutable world snapshot against one immutable model version.

### Grok task LOGIC-1

Recommend the smallest operator set that remains expressive enough for safety/contract/approval state machines while maximising auditability and coverage analysis.

Specifically decide whether the first real language should have:

```text
ALL / ANY only
AND / OR
NOT
XOR
IMPLIES
ELSE
DEFAULT
EXCEPT
UNLESS
```

For every retained operator, define exact precedence and associativity. Prefer requiring parentheses/grouping over relying on precedence if that is safer.

---

## 8. Current reference RYTA state rules

Three facts drive the current reference safety case:

```text
ESSENTIAL_MEDICATION
IMMEDIATE_ACCESS
GUARANTEED_CUSTODY
```

Each may be:

```text
KNOWN_TRUE
KNOWN_FALSE
UNKNOWN
CONFLICT
```

Current winning-rule precedence:

```text
100  any critical CONFLICT -> ESCALATE
 90  else any critical UNKNOWN -> NEEDS_INFORMATION
 80  else ESSENTIAL_MEDICATION false OR IMMEDIATE_ACCESS false -> NORMAL
 70  else both are true AND GUARANTEED_CUSTODY false -> REMEDIATION_REQUIRED
 60  else both are true AND GUARANTEED_CUSTODY true -> NORMAL
```

This covers all 4^3 = 64 epistemic combinations in the current test harness.

### Important caveat

Numeric rule priority is a provisional implementation mechanism, not an endorsed final language design.

### Grok task PRECEDENCE-1

Compare at least these precedence models:

1. numeric priority;
2. named priority tiers;
3. explicit `OVERRIDES <rule-id>` edges;
4. specificity ordering;
5. decision-table hit policies;
6. reject any overlapping hard rules unless the overlap is explicitly declared.

Recommend one for the first production-capable HardWorld language.

The recommendation must answer:

- How are ties detected?
- Can two matching rules with the same final state coexist?
- What if matching rules produce different effects but the same state?
- What if one rule requires an action and another prohibits it?
- What if one rule is lower priority but represents a non-overrideable safety invariant?
- How are unreachable/shadowed rules reported?

---

## 9. Effect language

Current action dispositions are:

```text
REQUIRED
PERMITTED
SUPPRESSED
PROHIBITED
REQUIRES_APPROVAL
```

Proposed meanings:

### REQUIRED
Execute/select the action regardless of its preference score, subject only to execution capability and any separately explicit impossibility handling.

### PERMITTED
The hard model allows the action. The preference/scoring algorithm may select or decline it.

### SUPPRESSED
Do not execute/select the action in this state, but the suppression represents policy/interaction choice rather than an intrinsic hard prohibition. It remains auditable as distinct from `PROHIBITED`.

### PROHIBITED
The action is not eligible. Preference score is irrelevant.

### REQUIRES_APPROVAL
The action is eligible only if its preference logic selects it **and** a valid approval satisfying the declared authority/scope rule exists.

### Grok task EFFECT-1

Attack these definitions.

In particular:

- Is `SUPPRESSED` semantically useful or does it create an unsafe middle ground?
- Should `REQUIRED` be split into `MUST_SELECT` and `MUST_EXECUTE_IF_CAPABLE`?
- How should an impossible REQUIRED action change state?
- Should `PERMITTED` mean merely "not prohibited" or affirmative permission from an authority?
- Should state transitions and action effects be separate output relations?

Return a revised effect lattice or explicitly say that no lattice should be assumed.

---

## 10. Approval and authority semantics

Current testbed has a minimal approval gate:

```text
BIG_UPSELL
  disposition = REQUIRES_APPROVAL
  authority = SALES_MANAGER
```

A matching approval allows a positively scored BIG_UPSELL to proceed.

The same approval does **not** alter BIG_UPSELL when the safety state says `PROHIBITED`.

### Proposed approval object fields

Future shape:

```text
approval_id
authority_identity
authority_role
authority_domain
scope
action_or_effect
rule_id
model_id
model_version
world_snapshot_oid
issued_at
expires_at
quorum_group
signature_or_receipt
status
```

### Proposed override policy

A rule/effect should explicitly declare one of:

```text
NON_OVERRIDEABLE
REQUIRES_APPROVAL <authority-policy>
OVERRIDEABLE_BY <authority-policy>
```

No other implicit override exists.

### Grok task APPROVAL-1

Define the distinction between:

```text
permission
authority
approval
exception
override
waiver
delegation
quorum
capability
```

Then propose exact machine semantics that prevent these concepts being silently conflated.

Include stale approval, wrong-scope approval, approval for a different world snapshot, revoked approval, conflicting approvals and quorum failure.

---

## 11. Rules-and-holes coverage problem

We need to be able to answer, mechanically:

> For the declared input domain, which combinations are handled, which are ambiguous, which fall through, which are unreachable, and which actions lack a disposition?

The current test enumerates all 64 combinations of the three four-state critical facts.

That is only the beginning.

### Required coverage classes

A production coverage report should detect at least:

```text
C1  INPUT DOMAIN HOLE
    A valid input vector has no winning decision/state.

C2  RULE OVERLAP
    Multiple rules match the same vector.

C3  CONFLICTING WINNER
    Equal-precedence/equivalent authority rules imply incompatible states/effects.

C4  SHADOWED RULE
    A rule can match but can never win.

C5  UNREACHABLE RULE
    No valid input vector can satisfy the rule.

C6  ACTION DISPOSITION HOLE
    A reachable state leaves an action without an explicit disposition.

C7  STATE TRANSITION HOLE
    A reachable state/event pair has no legal transition where one is required.

C8  ILLEGAL TRANSITION
    A rule attempts a transition not declared by the state model.

C9  APPROVAL HOLE
    An action requires approval but the authority/scope policy is undefined.

C10 OVERRIDE HOLE
    A supposed override has no explicit authority relationship to the effect being overridden.

C11 EPISTEMIC COLLAPSE
    UNKNOWN or CONFLICT accidentally takes the same path as FALSE without an explicit rule.

C12 SCORE LEAK
    Changing a preference score changes a hard REQUIRED/PROHIBITED result.

C13 DEFAULT FALL-THROUGH
    A default hides an unmodelled case rather than documenting it.

C14 MODEL VERSION HOLE
    A decision cannot identify the exact rule/model version used.

C15 PROVENANCE HOLE
    A decision-relevant fact cannot identify its source/authority.
```

### Grok task COVERAGE-1

Critique this taxonomy and produce a better one if needed.

For each coverage class provide:

1. formal detection criterion;
2. whether it can be caught statically, dynamically, or both;
3. minimum test evidence;
4. severity classification;
5. whether deployment should fail closed.

---

## 12. Coverage metrics we are considering

Do not assume ordinary code coverage is adequate.

Candidate decision coverage metrics:

```text
input_domain_coverage
rule_condition_true_coverage
rule_condition_false_coverage
rule_match_coverage
rule_win_coverage
rule_shadow_coverage
state_coverage
transition_coverage
effect_required_coverage
effect_prohibited_coverage
effect_permitted_coverage
effect_approval_coverage
unknown_path_coverage
conflict_path_coverage
approval_success_coverage
approval_failure_coverage
hard_score_invariance_coverage
```

For small finite domains, exhaustive enumeration is preferred.

For larger domains, propose how to combine:

```text
boundary-value analysis
pairwise / t-wise combinatorics
symbolic constraint solving
property-based generation
mutation testing
state-transition traversal
explicit safety invariants
```

### Grok task COVERAGE-2

Propose a machine-readable coverage manifest capable of declaring:

- fact domains;
- required combinations or combinatorial strength;
- expected winning states;
- expected mandatory/prohibited effects;
- explicit exclusions with reasons;
- known overlaps with precedence justification;
- minimum approval tests;
- required mutation survivors = 0 for selected mutations.

---

## 13. Mutation tests we want

A mature ruleset should fail tests if any of these mutations are introduced:

```text
M1  KNOWN_TRUE -> KNOWN_FALSE
M2  UNKNOWN -> KNOWN_FALSE
M3  CONFLICT -> UNKNOWN
M4  ALL -> ANY
M5  ANY -> ALL
M6  REQUIRED -> PERMITTED
M7  PROHIBITED -> SUPPRESSED
M8  PROHIBITED -> PERMITTED
M9  remove a rule clause
M10 remove a rule
M11 change rule precedence
M12 remove approval requirement
M13 widen approval scope
M14 change NON_OVERRIDEABLE to overrideable
M15 change state target
M16 allow score to participate in hard-rule precedence
```

### Grok task MUTATION-1

Extend this list with mutations that are especially good at discovering policy-language ambiguities rather than ordinary coding defects.

---

## 14. Reference decision vectors

Use these when evaluating your proposed semantics.

### V1 — normal commercial path

```text
ESSENTIAL_MEDICATION = KNOWN_FALSE
IMMEDIATE_ACCESS     = KNOWN_FALSE
GUARANTEED_CUSTODY   = KNOWN_TRUE
PRODUCT_VALUE_HIGH   = KNOWN_TRUE
UPSELL_OPPORTUNITY   = KNOWN_TRUE
```

Expected state:

```text
NORMAL
```

BIG_UPSELL may be elected by score unless another explicit rule constrains it.

### V2 — hard safety remediation

```text
ESSENTIAL_MEDICATION = KNOWN_TRUE
IMMEDIATE_ACCESS     = KNOWN_TRUE
GUARANTEED_CUSTODY   = KNOWN_FALSE
```

Expected state:

```text
REMEDIATION_REQUIRED
```

Expected effects:

```text
WARNING      REQUIRED
SELL_PRODUCT SUPPRESSED
UPSELL       PROHIBITED
BIG_UPSELL   PROHIBITED
```

Even if:

```text
BIG_UPSELL score = +1,000,000
WARNING score    = -1,000,000
```

expected final selection still includes WARNING and excludes BIG_UPSELL.

### V3 — missing critical fact

```text
ESSENTIAL_MEDICATION = KNOWN_TRUE
IMMEDIATE_ACCESS     = KNOWN_TRUE
GUARANTEED_CUSTODY   = UNKNOWN
```

Expected state:

```text
NEEDS_INFORMATION
```

Expected:

```text
ASK_INFORMATION REQUIRED
```

### V4 — conflict outranks unknown

```text
ESSENTIAL_MEDICATION = KNOWN_TRUE
IMMEDIATE_ACCESS     = CONFLICT
GUARANTEED_CUSTODY   = UNKNOWN
```

Current expected state:

```text
ESCALATE
```

This explicitly tests precedence of contradictory evidence over merely absent evidence.

### V5 — approval gate

```text
state = NORMAL
BIG_UPSELL score > 0
BIG_UPSELL_REVIEW_REQUIRED = KNOWN_TRUE
```

Without valid SALES_MANAGER approval:

```text
BIG_UPSELL final = false
```

With valid approval scoped to BIG_UPSELL:

```text
BIG_UPSELL final = true
```

### V6 — approval cannot negate prohibition

Same valid approval, but state is `REMEDIATION_REQUIRED`.

Expected:

```text
BIG_UPSELL PROHIBITED
BIG_UPSELL final = false
```

---

## 15. State-machine issues for you to attack

Please explicitly analyse:

1. Entry actions versus state effects.
2. Exit actions.
3. Transition guards.
4. Multiple simultaneously enabled transitions.
5. Transition priority.
6. Self-transitions.
7. Terminal states.
8. Error/unknown states.
9. Impossible mandatory actions.
10. Re-evaluation after remediation.
11. Whether new facts require a new immutable decision run rather than mutation of the old run.
12. Temporal validity of facts and rules.
13. Approval expiry during a state transition.
14. Whether state machines should be hierarchical.
15. Whether concurrency/orthogonal states belong in the first language or should be excluded initially.

Prefer a smaller first language if a feature makes coverage or auditability substantially harder.

---

## 16. Plugin boundary

The wider architecture will plug in deterministic capabilities from other components using narrow ooRexx `.cls` adapters.

Expected plugin families:

```text
FACT PLUGIN
    contributes typed facts + provenance

SCORE PLUGIN
    contributes preference adjustments

STATE/RULE PLUGIN
    contributes versioned rules/state definitions

APPROVAL PLUGIN
    validates authority, scope, expiry, quorum
```

A plugin MUST NOT receive the Virtual RYTA actor solely so it can directly call action methods. Plugins influence the decision; the final dispatcher executes it.

Future examples:

```text
Camera -> fact/algorithm relation plugin
Librarian -> deterministic category/fact plugin
meaning-scoring matrix -> score/fact plugin
NoSQLServer -> AlgorithmRelation adapter
```

### Grok task PLUGIN-1

Identify the minimum plugin contract fields required to keep:

- provenance;
- versioning;
- deterministic replay;
- capability declaration;
- authority boundaries;
- coverage accounting.

---

## 17. Algorithm-as-a-Relation destination

The eventual NoSQLServer integration should be able to expose a decision run relationally, approximately:

```text
action_code
score
provisional_selected
state
disposition
required_authority
final_selected
winning_rule
output
```

Additional relations may expose:

```text
world facts
rule matches
state transitions
rule firings
approval checks
provenance
coverage report
```

The SQL layer should not need to know whether the producing algorithm is a state machine, deterministic categoriser, scoring matrix, camera behaviour model or future LLM-backed algorithm.

### Grok task RELATION-1

Recommend what must be present in the relational contract to preserve explainability and auditability without leaking domain-specific implementation details.

---

## 18. Required structure of your response

Return your response in the following sections so it can be consumed mechanically or merged by another implementation agent.

### A. EXECUTIVE FINDING

Maximum 20 lines. State whether the proposed direction is viable and name the three highest-risk semantic ambiguities.

### B. NORMATIVE VOCABULARY TABLE

Columns:

```text
TERM
CLASS
ALLOWED_IN_EXECUTABLE_RULES
EXACT_MACHINE_SEMANTICS
DANGEROUS_ALIASES
NOTES
```

### C. LOGIC / OPERATOR TABLE

Columns:

```text
OPERATOR
KEEP_OR_REJECT
ARITY
SEMANTICS
PRECEDENCE
UNKNOWN_HANDLING
CONFLICT_HANDLING
COVERAGE_OBLIGATION
```

### D. EPISTEMIC MODEL

Provide exact semantics and truth tables if applicable.

### E. RULE PRECEDENCE AND CONFLICT ALGORITHM

Provide deterministic pseudocode.

### F. EFFECT AND APPROVAL MODEL

Give exact machine states and override rules.

### G. RULES-AND-HOLES COVERAGE MODEL

Provide detection rules and report schema.

### H. MINIMUM RULE LANGUAGE

Give a proposed grammar or EBNF-like syntax. Keep it deliberately small.

### I. ADVERSARIAL CORPUS

At least 25 rules or input cases designed to expose semantic ambiguity, including:

```text
mixed AND/OR
NOT with UNKNOWN
NOT with CONFLICT
MUST versus SHOULD
CAN versus MAY
CANNOT versus MUST NOT
MIGHT ambiguity
conflicting requirements
conflicting prohibitions
required impossible action
approval wrong scope
approval stale model version
approval stale world snapshot
rule overlap
rule shadowing
unreachable rule
default fall-through
exception scope
score attempting to defeat prohibition
score attempting to defeat requirement
```

### J. PROPOSED CHANGES TO VIRTUAL RYTA v0.1

Classify every change as:

```text
BLOCKER
SHOULD_DO_NEXT
DEFER
REJECT
```

### K. QUESTIONS THAT MUST BE ANSWERED BEFORE A PRODUCTION RULE LANGUAGE

List anything still semantically undecidable.

---

## 19. Constraints on your review

1. Do not assume an LLM is present.
2. Do not replace hard rules with probabilistic confidence scores.
3. Do not solve contradictions by averaging scores.
4. Do not treat UNKNOWN as FALSE.
5. Do not treat CONFLICT as UNKNOWN without an explicit policy.
6. Do not allow an approval to negate a prohibition by default.
7. Do not use natural-language explanation as proof of a decision. The derivation trace is the proof.
8. Do not hide unspecified behaviour behind a convenient default.
9. Do not propose complexity unless you can state how its state/rule space will be covered.
10. Prefer a small language whose complete semantics can be tested over a broad language with undefined corners.

---

## 20. Standards background

Useful background, not automatically adopted as executable semantics:

- IETF BCP 14: RFC 2119 and RFC 8174 — conventional requirement levels such as MUST, MUST NOT, SHOULD and MAY, plus the capitalization clarification.
- OMG Decision Model and Notation (DMN) — useful comparison point for decision tables, decision requirements and hit-policy concepts.
- Standards-drafting practice commonly distinguishes requirement, recommendation, permission and capability/possibility; HardWorld must make these distinctions machine-exact rather than relying on prose convention.

The project specification must remain self-contained. Do not answer by saying "use RFC/ISO/DMN semantics" without spelling out the resulting machine behaviour.

---

## 21. One-line design test

If your proposed language cannot answer the following without ambiguity, it is not ready:

> BIG_UPSELL scores +1,000,000; WARNING scores -1,000,000; essential medication requires immediate access; guaranteed cabin custody is false. Which methods execute, which are prohibited, what rule caused that result, what could an approval change, and what could no approval change?

