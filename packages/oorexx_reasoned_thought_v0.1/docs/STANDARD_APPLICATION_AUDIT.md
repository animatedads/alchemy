# StandardApplicationAudit/0.3 — stated-standard consistency (authoritative operator)

**Architecture:** Tom Dyer. **Operator:** ChatGPT GPT-6. **Reference and adversarial test owner:** Claude (Opus 4.8). Pure ooRexx 5.3; no native library dependencies in the operator.

## Scope

`StandardApplicationAudit` tests whether **declared** applications of **one declared standard** have a structural ordering contradiction. It **does not** determine truth, source authenticity, legal outcomes, statistical bias, or whether the standard is just. Every result contains `validatedTruth=.false`, `scope='STANDARD_APPLICATION_CONSISTENCY_ONLY'`, `evidenceAuthority='CALLER_DECLARED_NOT_AUTHENTICATED'` and `universalConsistencyProven=.false`. The `classification` names a comparison result **conditional on the supplied representations**, not an adjudication.

## API (reference compatible)

- `~standard(id, kind, dimension, required='', description='', direction='HIGHER_WORSE')`; `kind` is `DISQUALIFY` or `THRESHOLD`; severity direction is `HIGHER_WORSE` or `LOWER_WORSE`.
- `~applied(id, chainId, value, disposition, dimension='', measurementBasis='')`; disposition is `ACCEPTED` or `REJECTED`. The new dimension/basis arguments are optional to retain the published four-argument interface. Omitting both means *assumed identical*, **not verified comparable**. `UNKNOWN` is never interpreted as zero. A chain ID can occur once per standard.
- `~selfMaterial(id, tier)`; a declared numerical tier for a threshold comparison. It presumes the **same rule** applies to the decision-maker's material; the operator cannot authenticate that assumption.
- `~audit(id)` returns a Directory with `classification`, `pairs`, `incomparablePairs`, `reasonCodes`, `comparablePairs`, `observations`, `validatedTruth`, `scope`, `detail` and related diagnostics.

## Classification semantics

For DISQUALIFY *without an explicit `required` boundary*, an accepted chain with **at least as serious a problem** as a rejected comparable chain is a structural counterexample, `DISPARATE_TREATMENT`. If no counterexample exists among **all comparable measured pairs**, `CONSISTENT_APPLICATION` means only **no ordering contradiction detected within the finite declared dataset**. If cases lack comparable dimension, measurement basis or known numeric values, use `INDETERMINATE_COMPARABILITY`. With fewer than two applications, use `INSUFFICIENT_APPLICATIONS`. When a counterexample exists alongside incomparable cases, report the detected counterexample *and* preserve the incomplete-comparability diagnostics.

When `DISQUALIFY` has an explicit numeric `required` boundary, compare **each** measured, on-dimension application to the declared cutoff as well as comparing applications to one another. In `HIGHER_WORSE`, values >= cutoff predict REJECTED; `LOWER_WORSE` reverses the comparator. Two equally erroneous accepts or rejects must be detectable even though they are pairwise consistent. Output `ruleViolations` (individual chain, value, actual/expected disposition, boundary and basis), plus `ruleConformingCases`. Use `STATED_RULE_VIOLATION` if the absolute violation has no pairwise disparity; retain `DISPARATE_TREATMENT` when both types occur and record both reason codes. One measured case can falsify an explicit cutoff; with no boundary the old two-case requirement remains. UNKNOWN and off-dimension measurements cannot become rule violations. These results remain **conditional on the caller's asserted inputs and complete rule representation**; unmodelled exceptions must be investigated independently. A rule violating its own threshold does not prove unlawful treatment or any underlying claim.

For THRESHOLD, the prior fixture's `UNMEETABLE_BAR` label is preserved where own material is declared below the stated bar, but the operator explicitly explains it as a **conditional SELF-STANDARD GAP**. It does not mean no claimant can ever meet that bar or prove the decision-maker must use the same evidence rule on its own claims. Missing self material is `INSUFFICIENT_SELF_MATERIAL`. The comparison is limited to one explicitly stated numerical threshold; it is not a legal standard-of-proof evaluator.

## Acceptance/qualification and limits

- Claude's existing `tests/test_standard_application_audit.rex` remains wholly **Claude-owned and unchanged**. Its seven `check` invocations cover equal/worse/opposite outcomes, justified differences, threshold gaps, and scope ceiling.
- Owner-side `tests/test_standard_application_contract_gpt6.rex` performs **21 native checks** including those reference behaviours and incomparable dimensions, incompatible measurement bases, unknown values, absent comparisons, a reversed severity scale, and partial coverage. Executed against user-supplied ooRexx **5.3.0 r13196**: `OWNER CONTRACT PASS: 21 checks`. The separate `tests/test_standard_application_absolute_rule_gpt6.rex` falsifies v0.2 on its first check, and passes **13/13** checks on v0.3, with 21/21 previous checks remaining green.
- This proves specified **synthetic behaviour**, not correctness of real-world admission choices. No source verification is built into the operator. No case-specific data enters this source.
- Independent adversarial testing is **not** replaced by an implementer's green tests. Claude owns further falsifiers and suite integration. The other open proposal, descriptive/normative/definitional premise typing, remains Claude's ConceptHierarchy/categorisation work.

## Red-team observations

- A zero- or one-application set formerly returned `CONSISTENT_APPLICATION` without having compared anything; now `INSUFFICIENT_APPLICATIONS`.
- Two cases with different sources, measurement dimensions, or measurement bases can have different numeric values and dispositions without being comparable; now these return `INDETERMINATE_COMPARABILITY` unless a separate valid counterexample exists.
- Uniformly wrong outcomes can be pairwise consistent despite violating an absolute stated rule; the new explicit-boundary path detects these without changing the four-argument legacy `applied` API.
- A threshold with no selfMaterial formerly returned `CONSISTENT_APPLICATION`; now `INSUFFICIENT_SELF_MATERIAL`.
- The old label `UNMEETABLE_BAR` is retained for fixture compatibility but no longer described as an impossible standard; the result is conditional on the applicability of the standard to both sides.
- The prior test 14 and test 15 `check:` subroutines use `procedure` without `expose checks`, so terminal `checks` reporting is not trustworthy. Their individual PASS/FAIL diagnostics still evaluate each test. This is a **Claude-owned fixture reporting fix**, not an operator change.

## Owner boundary

ChatGPT owns this operator and its independent contract test. Claude owns `FactsMatrix`, `BeliefJournal`, the standard-application adversarial fixture, shared runner and separate premise-typing work. No automatic merge and no private case data.

### Label/order-invariance continuation

A supplementary 7-check owner-side regression reproduces the five public
structural vectors from Claude's separate test 16 (without modifying that
fixture), then adds two explicit-cutoff invariants for label permutation and
insertion order. It passes 7/7 on the revised operator. The complete fresh
extraction qualification now totals 21 + 13 + 7 = **41 native checks**.
Independent acceptance remains Claude's responsibility; this extra coverage
is not misrepresented as independent validation.

## v0.4 — necessary-threshold consistency (27 October 2026)

A THRESHOLD represents a **necessary condition for ACCEPTANCE**, not a sufficient
condition. When the decision-maker states a minimum evidence tier of 3:

- ACCEPTED at tier 2 on the same declared dimension and basis is a
  STATED_RULE_VIOLATION (conditional on the caller's unverified input).
- REJECTED at tier 4 is **not** a violation without an additional warrant saying
  the tier is sufficient for acceptance; other objections may justify rejection.
- An application using another measurement dimension, scale/basis or unknown value
  cannot be ordered against the minimum: INDETERMINATE_COMPARABILITY unless
  some other valid counterexample has already been established.
- When a self-material gap and a directly observed threshold violation coexist,
  the report retains **both** through selfStandardGap and reasonCodes.
- If no self-material tier is supplied but an accepted case is below the stated
  minimum, preserve the directly supported rule violation rather than silently
  discarding it. The self-tier remains .nil (unknown).

For explicit scales, the final optional parameter of standard() is
requiredBasis:

    a~standard('S','THRESHOLD','evidence',3,'','HIGHER_WORSE','ordinal:v1')
    a~applied('S','CASE1',2,'ACCEPTED','evidence','ordinal:v1')

Absent this parameter, the caller's omission asserts a shared basis
ASSUMED_EQUIVALENT:S for compatibility with existing tests. It is not source
authentication or independent evidence of metric comparability. The public API
remains audit(standardId); outputs add ruleViolations, ruleConformingCases,
uncomparableCases, ruleBasis and selfStandardGap.

**Native test evidence:** on user-supplied ooRexx 5.3.0 r13196,
test_standard_application_contract_gpt6.rex 21/21 PASS and
test_threshold_necessary.rex 19/19 PASS. Those are implementer-side tests.
Claude's independent fixtures test_standard_application_audit.rex (test 15)
and test_standard_application_fairness.rex (test 16) remain separately owned
and require independent qualification before merging this operator.

Neither a structural violation nor a conditional self-standard gap proves that
the stated rule is fair, that inputs are genuine, or that any underlying claim is
true. The operator never outputs a merits verdict.

## v0.5 — do not certify unresolved cases or mix score scales

Review of the v0.4 threshold report found that REJECTED cases at or above
a minimum were being counted in ruleConformingCases. That is too strong:
meeting a NECESSARY minimum does not guarantee acceptance. They now appear
in unresolvedDispositionCases. Conforming cases are restricted to ACCEPTED
at or above the bound minimum or REJECTED below it. No real-world truth or
legal correctness is implied.

A DISQUALIFY rule with an explicit absolute boundary also compares values
only when the application's basis equals the requiredBasis declared by the
standard. Two entries that use the same unrelated score scale do not become
comparable to an ordinal threshold merely because they agree with each other.
The audit records STANDARD_BASIS_MISMATCH and INDETERMINATE_COMPARABILITY
rather than generating false threshold violations.

Native evidence for this revision: user-supplied ooRexx 5.3.0 r13196,
existing owner contract 21/21 PASS plus threshold necessity and basis suite
24/24 PASS. This is 45 owner-side assertions, not Claude's independent
adversarial acceptance. The complete runner now invokes the threshold
suite alongside the other owner suites.
