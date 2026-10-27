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
