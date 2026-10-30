# MAH (Egypt) — real published judgment / domain-neutral Reasoned Thought fixture

Public, anonymised Court of Appeal case: **MAH (Egypt) v Secretary of State for the Home Department [2023] EWCA Civ 216**, judgment of 28 February 2023. This is a public-source *reasoning audit* fixture, not a prediction of the appellant's merit or a tool-made refugee determination.

## Inputs and attribution

- Authoritative judgment: https://caselaw.nationalarchives.gov.uk/ewca/civ/2023/216
- Claude (Opus 4.8) dossier: `../MAH_EGYPT_EVIDENCE_FOR_MODEL.md` in Git; prepared at `6bde665c` (source blob `bcfd4217...`). Quotations checked against the official judgment before modelling.
- Architecture: Tom Dyer; evidence research/write-up: Claude; model / test implementation: ChatGPT GPT-6.
- This fixture contains **no private case data**. Public anonymised judgment only.

## What actually executes

`JudgmentReasoningLedger.cls` is a generic, source-anchored trace of legal/administrative reasoning: source actor, type, citation, proposition and named correction edge. The auditor refuses to turn an Upper Tribunal (UT) position into a Court of Appeal (CA) finding. All conclusions remain court-*reported*, not externally truth-certified.

The v0.2 ledger additionally checks that every correction edge joins compatible **proposition kinds**, not merely compatible judicial actors. Duplicated edges remain visible in the raw history but count only once among qualified findings; rejected edges carry an explicit `RELATION_KIND_MISMATCH`, `RELATION_ACTOR_MISMATCH`, or `DUPLICATE_RELATION` reason. `citationValidated=.false` records that matching paragraph strings to the published judgment is an external validation task. `DISTINGUISHES_ISSUES` remains declared but unqualified until a proposition-kind contract is defined.

`test_mah_judgment.rex` also invokes the **real** `StandardApplicationAudit.cls` (version 0.5, independently reviewed by Claude) and the repaired **real** `WorldEnsemble.cls` from the synthetic Vanishing Dinner qualification. The standard audit correctly returns `INDETERMINATE_COMPARABILITY` for three distinct requests for missing corroboration: there are no grounded, calibrated scores for comparing them. The countermodel preserves all recorded court outcomes while independently varying hypothetical future risk and truthfulness, demonstrating non-entailment.

```sh
REXX_BIN=/path/to/rexx sh tests/run.sh
```

When checked out within the canonical Alchemy tree, the runner loads existing `../../src/StandardApplicationAudit.cls` and `../../tests/vanishing_dinner/WorldEnsemble.cls`. A *standalone* ZIP includes pinned copies under `vendor/` and uses those instead. No Python or native add-ons are required (other than the ooRexx interpreter).

## Native qualification and its ceiling

Locally run against ooRexx **5.3.0 r13196** from the user-supplied Linux package: **46/46 PASS (25 original + 9 edge-integrity + 12 source-node integrity)**. The original suite checks: judicial actor/source boundaries, lower-standard versus operative-high-threshold reasoning as a court finding, the non-mandatory but potentially probative nature of absent corroboration, the Art 4(5)/339L inverse fallacy, conflation between credibility and claim merit, omitted family-visit testimony, CA remaking, rejected alternative appeal grounds, negative comparisons without invented numbers, and independent countermodel dimensions.

The separate `test_mah_edge_soundness.rex` first failed against v0.1, then passed 9/9 after the v0.2 repair. Its false-relationship and duplicate-edge cases are synthetic, not additional allegations about the court.

Not claimed: fresh adjudication, quantified legal standard, authentication of original witness or expert evidence, actual future persecution probability, causal proof of why every appellate judge agreed, or proof that all relevant questions and evidence have been encoded. The appellate outcome is recorded as an input **because the court made it**, not computed from assumptions.

See `docs/JUDGMENT_PROVENANCE.md` for paragraph-by-paragraph sources, constraints, known limitations and replication details.

## Source integrity v0.3

`node()` returns a detached snapshot rather than a mutable internal record. The audit refuses self-qualifying edges (`SELF_RELATION`). Native r13196 qualification: 25 original, 9 edge-soundness, and 12 source-integrity checks pass (46 total). `citationValidated=false` remains: the software does not independently authenticate paragraph content or verify that a quoted passage supports its proposition. This is an audit of the published judicial reasoning, not a fresh asylum determination.
