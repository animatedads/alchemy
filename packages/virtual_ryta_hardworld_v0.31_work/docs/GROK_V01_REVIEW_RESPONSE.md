**A. EXECUTIVE FINDING**

The direction is viable and unusually well-engineered for a safety-critical decision substrate. The separation of preference scoring from hard eligibility, the explicit epistemic states, and the refusal to let scores defeat `PROHIBITED`/`REQUIRED` are the correct foundations.

Three highest-risk semantic ambiguities remain:

1. **Numeric priority as the production precedence mechanism** is still too close to “magic number” and will eventually be gamed or misunderstood. Named tiers + explicit `OVERRIDES` edges are safer.
2. **`SUPPRESSED` versus `PROHIBITED`** currently lacks a crisp, testable distinction that auditors will not collapse.
3. **Approval scope binding** (world snapshot + model version + action) is specified in spirit but not yet locked down tightly enough to prevent stale or cross-context approvals.

Everything else can be made unambiguous with a deliberately small first language.

---

**B. NORMATIVE VOCABULARY TABLE**

| TERM              | CLASS          | ALLOWED_IN_EXECUTABLE_RULES | EXACT_MACHINE_SEMANTICS                                                                 | DANGEROUS_ALIASES                  | NOTES |
|-------------------|----------------|-----------------------------|------------------------------------------------------------------------------------------|------------------------------------|-------|
| MUST / REQUIRED   | Hard obligation| Yes                        | Action/effect is selected regardless of score (subject only to capability)              | “should really”, “expected”        | Keep |
| MUST NOT / PROHIBITED | Hard prohibition | Yes                   | Action is ineligible; score is ignored                                                  | “mustn’t”, “should not”            | Keep |
| SHOULD / RECOMMENDED | Soft recommendation | No (v1)             | Move to `RECOMMENDED` + explicit `DEVIATION_POLICY` if needed later                     | “normally”, “usually”              | Ban from executable rules in v1 |
| SHOULD NOT / NOT_RECOMMENDED | Soft | No (v1)                | Same as above                                                                           |                                    | Ban |
| MAY / PERMITTED   | Permission     | Yes                        | Not prohibited; preference algorithm may select                                         | “can”, “allowed”                   | Keep; do **not** imply authority |
| CAN / CANNOT      | Capability     | Yes (as fact only)         | Describes possibility/capability, never authority or permission                         | “may”, “might”                     | Allowed only as facts, never as normative operators |
| MIGHT / COULD     | Uncertain possibility | No                     | Rewrite into explicit epistemic or possibility fact                                     |                                    | Banned |
| UNLESS / EXCEPT   | Exception      | No                         | Rewrite as positive conditions on separate rules                                        |                                    | Banned |

---

**C. LOGIC / OPERATOR TABLE**

| OPERATOR | KEEP_OR_REJECT | ARITY | SEMANTICS                                      | PRECEDENCE | UNKNOWN_HANDLING          | CONFLICT_HANDLING         | COVERAGE_OBLIGATION |
|----------|----------------|-------|------------------------------------------------|------------|---------------------------|---------------------------|---------------------|
| ALL      | Keep           | n-ary | All clauses match                              | N/A (explicit) | Clause-level only        | Clause-level only        | Must enumerate |
| ANY      | Keep           | n-ary | At least one clause matches                    | N/A        | Clause-level only        | Clause-level only        | Must enumerate |
| AND      | Reject (v1)    | -     | Use ALL                                        | -          | -                         | -                         | - |
| OR       | Reject (v1)    | -     | Use ANY                                        | -          | -                         | -                         | - |
| NOT      | Reject (v1)    | -     | Force explicit epistemic predicates            | -          | Dangerous                 | Dangerous                 | - |
| XOR      | Reject         | -     | -                                              | -          | -                         | -                         | - |
| IMPLIES  | Reject (v1)    | -     | Express as separate rules                      | -          | -                         | -                         | - |
| ELSE / DEFAULT | Reject (v1) | -  | Force explicit coverage of all vectors         | -          | Hides holes               | Hides holes               | - |
| UNLESS / EXCEPT | Reject    | -     | -                                              | -          | -                         | -                         | - |

**Recommendation:** First production language uses only explicit epistemic predicates + `ALL` / `ANY`. No raw four-valued Boolean operators. This maximises auditability and makes coverage analysis trivial.

---

**D. EPISTEMIC MODEL**

Retain the current separation. Do **not** introduce direct four-valued `AND`/`OR`/`NOT` in v1.

Allowed clause form only:

```text
<fact> KNOWN_TRUE
<fact> KNOWN_FALSE
<fact> UNKNOWN
<fact> CONFLICT
```

Semantics:

- `KNOWN_TRUE` / `KNOWN_FALSE` — accepted value exists.
- `UNKNOWN` — no accepted value.
- `CONFLICT` — mutually incompatible accepted claims exist.
- `UNKNOWN` and `CONFLICT` must never be coerced to `FALSE`.

This is the safest base. Four-valued operators can be considered later only after the coverage and mutation suites are mature.

---

**E. RULE PRECEDENCE AND CONFLICT ALGORITHM**

**Recommended model for v1:** Named priority tiers + explicit `OVERRIDES` edges + reject undeclared same-tier conflicts.

```text
tiers = { SAFETY_CRITICAL, SAFETY_NORMAL, OPERATIONAL, COMMERCIAL }

algorithm:
  collect all matching rules
  group by tier
  for highest non-empty tier:
      if >1 rule and effects/state conflict and no explicit OVERRIDES edge:
          → CONFLICTING_WINNER (fail closed or escalate)
      else apply effects of the winning set (or single winner)
  lower tiers are ignored unless an explicit OVERRIDES relationship exists
```

- Ties at the same tier with incompatible effects → hard error / escalate.
- Same state + compatible effects may coexist (recorded as overlap, not ambiguity).
- A `SAFETY_CRITICAL` rule can never be overridden by a lower tier.
- Unreachable and shadowed rules are reported by the coverage analyser.

Numeric priority should be demoted to an implementation detail of the current testbed only.

---

**F. EFFECT AND APPROVAL MODEL**

**Revised effect set (keep small):**

- `REQUIRED` — must be selected (subject only to capability).
- `PERMITTED` — not prohibited; preference may choose.
- `PROHIBITED` — ineligible; score irrelevant; non-overrideable by default.
- `REQUIRES_APPROVAL <policy>` — eligible only if preference selects it **and** a valid approval exists.
- Drop or tightly redefine `SUPPRESSED`. Prefer modelling commercial suppression as an explicit `PROHIBITED` under a named commercial-safety interaction rule, or keep `SUPPRESSED` only if it is defined as “policy choice, still auditable, never safety-critical”.

**Approval rules:**

- Approval never negates `PROHIBITED` unless the rule itself declares `OVERRIDEABLE_BY <policy>`.
- Approval object must bind: `model_id + model_version + world_snapshot_oid + action/effect + authority + scope + expiry`.
- Stale snapshot, wrong model version, wrong scope, expired, revoked, or insufficient quorum → approval invalid.
- `NON_OVERRIDEABLE` is the default for safety effects.

---

**G. RULES-AND-HOLES COVERAGE MODEL**

The taxonomy in the brief is already strong. Minor tightenings:

- Keep all C1–C15.
- Add **C16 SCORE_LEAK_INVARIANCE** as a first-class dynamic check (already present in spirit).
- Detection: static analysis for shadowing/unreachability where possible; exhaustive/dynamic for finite domains; mutation suite mandatory for safety-critical rule groups.
- Severity: any hole that can produce an incorrect `REQUIRED`/`PROHIBITED` result is deployment-blocking.
- Report schema should be relational from day one (ready for NoSQLServer AlgorithmRelation).

---

**H. MINIMUM RULE LANGUAGE (v1)**

```ebnf
rule        = "RULE" id "TIER" tier
              "WHEN" combinator "{" clause+ "}"
              "THEN" "{" effect+ "}"

combinator  = "ALL" | "ANY"
clause      = fact epistemic_pred
epistemic_pred = "KNOWN_TRUE" | "KNOWN_FALSE" | "UNKNOWN" | "CONFLICT"
effect      = "STATE" state
            | "REQUIRE" action
            | "PERMIT" action
            | "PROHIBIT" action
            | "REQUIRES_APPROVAL" action policy
            | "OVERRIDES" rule_id
```

No `UNLESS`, no mixed AND/OR without the explicit combinator, no open-world defaults.

---

**I. ADVERSARIAL CORPUS (selected high-value cases)**

1. Mixed implicit AND/OR without grouping  
2. `NOT UNKNOWN`  
3. `NOT CONFLICT`  
4. `MUST` vs `SHOULD` on same action  
5. `CAN` used as permission  
6. `CANNOT` vs `MUST NOT`  
7. `MIGHT` in a condition  
8. Two `REQUIRED` actions that are mutually exclusive  
9. `REQUIRED` + `PROHIBITED` on same action  
10. Required action that is currently impossible  
11. Approval with wrong scope  
12. Approval for previous model version  
13. Approval for different world snapshot  
14. Expired approval  
15. Conflicting approvals  
16. Rule overlap same tier, different state  
17. Shadowed lower-tier rule  
18. Unreachable rule  
19. Default fall-through hiding a vector  
20. Score +1e6 vs `PROHIBITED`  
21. Score –1e6 vs `REQUIRED`  
22. `UNKNOWN` coerced to false by weak implementation  
23. `CONFLICT` treated as `UNKNOWN`  
24. Approval used to override `NON_OVERRIDEABLE`  
25. Missing disposition for a reachable state/action pair  

(Extend with the full 64-vector matrix and the mutation list already defined.)

---

**J. PROPOSED CHANGES TO VIRTUAL RYTA v0.1**

| Change                                      | Classification   |
|---------------------------------------------|------------------|
| Replace numeric priority with named tiers + OVERRIDES | BLOCKER for production language |
| Freeze epistemic predicates only (no 4-valued ops) | SHOULD_DO_NEXT |
| Tighten approval binding (snapshot + model version) | SHOULD_DO_NEXT |
| Decide fate of `SUPPRESSED`                 | SHOULD_DO_NEXT |
| Keep current 64-vector exhaustive suite     | Keep |
| Add mutation runner for M1–M16              | SHOULD_DO_NEXT |
| Relational coverage output                  | SHOULD_DO_NEXT |
| Four-valued Boolean operators               | DEFER |
| Hierarchical/concurrent states              | DEFER |
| Natural-language rule parsing               | REJECT for v1 |

---

**K. QUESTIONS THAT MUST BE ANSWERED BEFORE A PRODUCTION RULE LANGUAGE**

1. Exact override lattice: which tiers may override which effects?
2. Is `SUPPRESSED` retained, and if so what is its formal distinction from `PROHIBITED`?
3. Capability failure of a `REQUIRED` action — new state or hard error?
4. Are same-tier compatible overlaps permitted or must every overlap be declared?
5. Temporal validity: do facts carry effective intervals, and does the evaluator enforce them?
6. Quorum and delegation model for multi-party approvals.
7. Whether the first language allows any form of `ELSE`/`DEFAULT` at all (current recommendation: no).

---

**Bottom line**

The Virtual RYTA / HardWorld v0.1 design is already one of the cleanest separations of preference versus authority I have seen in an agentic safety context. The single most important next step is to freeze a **small, fully enumerable, fully mutable-testable** rule language before any additional expressive power is added. Once that language can answer the one-line design test mechanically and without ambiguity, the rest of the Algorithm-as-a-Relation programme becomes straightforward.