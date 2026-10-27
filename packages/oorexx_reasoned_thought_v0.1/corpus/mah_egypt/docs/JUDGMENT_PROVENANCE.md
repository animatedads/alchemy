# MAH (Egypt) judicial trace — provenance and interpretation

Primary: The National Archives / Find Case Law: https://caselaw.nationalarchives.gov.uk/ewca/civ/2023/216

All descriptions in the fixtures are **short paraphrases** of the official judgment, not transcripts of testimony. `CA_JUDICIAL_FINDING` labels mean that Singh LJ **said or found** a proposition, not that a computer has independently established the real-world event. `UT_AS_REPORTED` labels mean that the appellate judgment reports the position taken by the Upper Tribunal. No evidentiary tier, severity, likelihood, or probability is inferred from these labels.

| Paragraph(s) of CA judgment | Point encoded | Scope / qualification |
| --- | --- | --- |
| 13–15, 23, 32–35 | UT accepted father's imprisonment and some contextual compatibility; rejected credibility on missing supporting evidence | Prior judicial treatment, not exhaustive historical record |
| 37, 49, 81 | Correct risk standard is reasonable degree of likelihood; CA found UT applied a higher substantive threshold | **Not** converted to a numerical `THRESHOLD` because the judgment provides no calibrated per-claim score |
| 74–77 | Art 4(5) Qualification Directive / the then-applicable Immigration Rules para 339L; failure to meet benefit-of-doubt criteria does not imply corroboration becomes compulsory | Applies to the regulatory period described by the judgment; not an assertion about every later statutory regime |
| 83, 90 | CA did not accept Grounds 2 or 4 | Negative findings retained to prevent outcome-biased selection |
| 86 | No general legal duty to corroborate; absence of reasonably obtainable evidence **may** matter | Two independent but compatible legal rules; do not flatten to “missing documents never count” |
| 87 | In these circumstances UT placed excessive weight on missing corroboration | Court's review of **this** record, not a universal evidentiary ban |
| 88 | UT's “untruthful” characterisation conflated credibility with failure to demonstrate a well-founded fear | Preserve proposition identity: witness veracity / claim merit / forward risk |
| 93 | UT omitted material positive testimony concerning previous family-home visits | Existence of evidence in the record is not proof an event happened, and omission from reasons is not proof of nonoccurrence |
| 94 | Expert country context included crackdown on human-rights lawyers and a state of emergency | Context bears on practical feasibility of suggested corroboration |
| 97 | Ground 6 not independently determinative | Preserve incomplete/partially unsuccessful grounds |
| 99, 102–104 | CA allowed and remade underlying appeal, finding refugee qualification on the evidence before both courts | Recorded judicial outcome, not a computer-generated determination |

## Why StandardApplicationAudit correctly refuses to score these claims

The statement that the UT used too high a legal standard is a **Court of Appeal finding**, not something a numeric threshold comparison can establish from the qualitative words “lower standard”. Our registered applications concerning a father's lawyer, a human-rights organisation and family witnesses are deliberately `UNKNOWN` for any common numeric scale and carry different observation bases. The v0.5 operator returns `INDETERMINATE_COMPARABILITY`, preserving the CA's independent legal assessment and refusing to invent disparity.

An `UNMEETABLE_BAR` status in the generic policy operator means only a **conditional self-standard tier gap** for numeric tiers on a common scale. The record at para 94 shows why securing corroboration might have been difficult; it does not establish a numerical impossibility theorem, a duty of the Egyptian lawyer to cooperate, or an authenticated scoring metric.

## What WorldEnsemble tests

The hypothetical worlds share three recorded observations: (1) UT accepted imprisonment, (2) UT dismissed the appeal, (3) CA later allowed it. Four deliberately counterfactual variants independently set `FUTURE_RISK` and `WITNESS_UNTRUTHFUL` true or false. These are **logical test worlds**, not competing findings that the appellant in the case lied or would be safe. The court's actual holding is represented by `CA_ALLOWED_APPEAL`, a different field from any independent forecast of danger.

Both `assess('FUTURE_RISK', 'YES')` and `assess('WITNESS_UNTRUTHFUL','YES')` return `UNDERDETERMINED`; `actualTruthProven` stays false. No evidentiary probability or automatic asylum outcome follows from the ensemble.

## Independent qualification request to Claude

1. Introduce a ground which the lower court rejected but the appellate court **also** rejected; prove the model does not reclassify it simply because the overall appeal succeeded.
2. Remove the `QUALIFIES_NO_DUTY` edge and verify the ledger cannot claim it has preserved the *permitted* evidential relevance of absent corroboration.
3. Attempt to use `StandardApplicationAudit` with an uncalibrated legal threshold or mismatched bases; the result should be a refusal/indeterminate classification, not an invented “disparate” outcome.
4. Exchange the actor classes of UT and CA on an alleged correction edge; it must no longer appear as a judicial correction.
5. Change a source paragraph reference; the trace must change, and a future primary-source verifier must detect inaccurate cites. The present ledger checks the **presence**, not the textual truth, of cited paragraphs.
6. Ensure every proposition in the ledger is defensibly grounded in the paragraph indicated, without importing findings from another person's case.

This is a partial source-grounded qualification fixture for the real engine. It should not be labelled full legal automation.
