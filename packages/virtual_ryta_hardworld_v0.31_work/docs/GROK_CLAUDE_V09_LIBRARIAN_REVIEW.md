# Adversarial review request — Librarian salvage / Algorithm Relation v0.9

Review this as hostile deterministic-system archaeology, not as a request for praise.

## Claims to attack

1. The class-library salvage changes only the declared mechanical delta.
2. `Relation~allAt(index)` is the correct native ooRexx replacement for every repaired keyed `allItems(index)` call.
3. Removing the executable bootstrap does not alter class/routine semantics used by the adapter.
4. The two `RESULT` local renames are behaviour-preserving repairs.
5. Librarian output is evidence/categorisation, not authority.
6. Catalog/schema discovery does not execute Librarian.
7. One logical materialisation executes Librarian at most once.
8. The six output relations are sufficient to reconstruct the analysis evidence used by downstream code.
9. Model identity is not honest unless every output-affecting WordNet/cache/target/gazetteer/grammar input is fingerprinted.
10. A shared resident `LibrarianAnalyzer` does not acquire sequence-dependent state that invalidates the determinism claim.
11. Input `BAG_UNORDERED` semantics are appropriate for independent documents; identify cases where document order must be explicit.
12. Duplicate documents and duplicate target hits retain bag semantics rather than silently deduplicating.
13. Unresolved words, Soundex candidates, morphology, exceptions and gazetteer matches remain distinguishable in relational output.
14. Target weight is never confused with confidence, truth or authority.
15. The explicit SQL mapping between Librarian target keys and downstream authority dispositions is visibly policy, not ontology.

## Particular attacks requested

- Find any additional ooRexx 5.3 API scars in the salvaged source.
- Find any additional use of special Rexx variables or object/string coercion hazards.
- Examine whether `LibrarianAnalyzer~analyseArticle` or any subordinate object mutates shared lexical/model state in a way that makes execution order observable.
- Define the exact model-state manifest needed for a real WordNet Librarian provider.
- Attack canonicalisation: uppercase keys, punctuation stripping, duplicate terms, POS ambiguity and Soundex fallback.
- Attack target expansion: duplicate weights, cycles, incoming/outgoing graph links and alias expansion.
- Attack evidence provenance: can a target hit be traced to target section, seed, expansion source and word coordinate without printed-text parsing?
- Attack failure behaviour when the input relation lacks `DOCUMENT_ID` or `TEXT`.
- Attack very large documents, many documents and pathological repeated tokens.
- Attack malicious text containing control characters, pipes, NUL-like content and Unicode outside the current canonical-key alphabet.
- Attack NoSQL schema/type rendering of Librarian scores and booleans.
- Attack the distinction between lexical score, target score, resolution confidence and downstream preference score.

## Required output

Return:

1. executive verdict;
2. production blockers;
3. salvage-delta correctness findings;
4. determinism/model-identity requirements;
5. evidence/authority boundary findings;
6. at least 30 adversarial cases;
7. at least 20 mutation tests;
8. proposed changes classified as BLOCKER / SHOULD_DO_NEXT / DEFER / REJECT.

Do not recommend an LLM categoriser merely because the deterministic rules are incomplete. The purpose of this review is to establish exactly what the deterministic Librarian does and does not guarantee.
