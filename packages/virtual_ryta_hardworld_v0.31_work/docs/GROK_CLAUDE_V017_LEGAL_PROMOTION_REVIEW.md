# Adversarial review brief: v0.17 Legal Effect promotion boundary

Please attack the claim that an authority-bearing HardWorld fact can be traced to a deterministic, pinned
legal evaluation and cannot change meaning under the same promotion identity.

## Required attacks

1. Mutate `LegalNorm~conditions` after `LegalRuleGeneration~seal` and verify raw Legal Effect v0.1 can change.
2. Mutate conditions during evaluation; v0.17 must issue no pinned envelope.
3. Mutate exceptions during evaluation.
4. Mutate jurisdiction claims during evaluation.
5. Replace/mutate temporal scope during evaluation.
6. Mutate a source evidence anchor or its metadata during evaluation.
7. Mutate a proposed `LegalAction` or one of its mutations during evaluation.
8. Mutate action-mutation source evidence during evaluation.
9. Mutate current-context facts during evaluation.
10. Mutate current-context fact source evidence during evaluation.
11. Mutate source bindings during evaluation.
12. Mutate context metadata during evaluation.
13. Mutate event/evaluation time during evaluation.
14. Supply an opaque non-canonical source object; authority must fail closed.
15. Supply a canonical object whose canonical text itself changes during evaluation.
16. Reorder norms and prove identity changes wherever v0.1 execution can observe that order.
17. Reorder jurisdiction claims and inspect both result and failure evidence.
18. Reorder semantically map-like source collections; identity should not change merely from map iteration.
19. Construct REVIEW + REQUIRES_OBLIGATION in both orders; authority should be refused rather than inherit
    incidental reduction order.
20. Construct BLOCKED plus those dispositions; verify the adapter's ambiguity guard is not over-broad.
21. Construct UNKNOWN/unresolved plus mixed dispositions; verify fail-closed behaviour.
22. Duplicate a promotion ID with different content; set insertion must reject it.
23. Same promotions in different insertion order; promotion-set identity must be identical.
24. Same target fact, agreeing authorised promotions; all provenance must survive in the bundle.
25. Same target fact, conflicting authorised values; HardWorld must become CONFLICT.
26. Mix authorised/refused/unresolved promotions for one fact and check application semantics.
27. Require SOURCE_SNAPSHOT but provide FROZEN_OBSERVATION; promotion must not apply.
28. Query `EVIDENCE_PROMOTIONS` repeatedly; provider must materialise once.
29. Query basis/trace before promotion rows; materialisation count must still be one.
30. Attempt SQL UPDATE/DELETE through NoSQLServer v0.71; no authority state may change.
31. PREPARE/FETCH promotion relations through msqlshim; no promotion may be applied as a side effect.
32. Attempt to sneak a rich/native object through a scalar SQL column by `STRING`; reject or explicitly project.
33. Use Structured Relation v0.7 XML and X12 conflicting facts; both native source objects must remain reachable.
34. Use v0.7 code-analysis `RichBusinessFact`; prove the bridge is format-neutral and does not upgrade finding
    confidence into legal authority.
35. Reparse identical structured source at a different wall-clock time; semantic evidence identity should not
    change solely because processing timestamps changed.
36. Change source mapping/annotation/provenance while keeping scalar value identical; authority input identity
    should change.
37. Change only a presentation/display string of a native object; identity should not depend on it.
38. Poison native source `STRING`; the rich/legal path should still work.
39. Mutate the original structured source object after rich evidence capture; pinned semantic evidence must not move.
40. Attempt concurrent first evaluation/materialisation and look for double execution or split promotion identity.

## Mutants worth adding

- trust `generation~sealed` without content hashing;
- hash only generation ID/version;
- hash action code but omit mutations;
- omit context metadata from input identity;
- omit fact source evidence from context identity;
- sort generation norms unconditionally;
- sort jurisdiction claims despite first-failure evidence semantics;
- allow opaque evidence as a placeholder token;
- generate promotions from a naked `LegalEffectAssessment`;
- let SQL SELECT call `EvidencePromotionApplier`;
- collapse conflicting promotions by first/last write;
- let score choose among promotion conflicts;
- treat `REVIEW_REQUIRED` as `PROHIBITED` in HardWorld;
- map a Structured Relation `CONFLICT` to known scalar value;
- serialize rich source objects using `~string`.

The desired result is not merely 40/40 green. Please identify any object reachable from generation, action,
context, assessment or promotion that can affect legal output but is omitted from the pinned closure.
