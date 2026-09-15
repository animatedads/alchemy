# Virtual RYTA / HardWorld v0.10 — Librarian hardening adversarial review

## Role

Attack the v0.10 Librarian hardening. Do not praise the design unless a claim survives a concrete counterexample.

The original v0.9 architectural boundary remains non-negotiable for this review:

> Librarian emits deterministic lexical/semantic evidence. It does not acquire HardWorld authority merely because it assigns a category, score, confidence, or target weight.

## Changes since v0.9

1. Explicit `LibrarianModelManifest` model closure.
2. WordNet helper covering data files, exception files, dbfiles membership/content, target definitions, gazetteer definitions, cache source, and analyzer configuration.
3. Dynamic re-hashing of model closure so lazy pre-materialisation drift is detectable.
4. Analyzer factory: fresh `LibrarianAnalyzer` per provider execution/materialisation.
5. Explicit `BAG_UNORDERED` versus `ORDERED` input semantics.
6. `LIBRARIAN_TARGET_HITS` expanded to structured surface/canonical/resolution/coordinate/seed/expansion provenance.
7. Special-variable/API salvage audit extended for RESULT/SIGL/RC and keyed Relation access.

## Claims to attack

C1. A `FILE_HASHED_COMPLETE` model manifest is sufficient to identify every model/data artefact used by the recovered loader **when the caller/builder correctly declares the model mode**.

C2. `LibrarianWordNetModelManifestBuilder` covers the output-affecting closure of the recovered direct WordNet loader: data.*, *.exc, optional dbfiles, targets, gazetteer, and declared configuration.

C3. In cache-load mode, hashing the cache plus targets/gazetteer/configuration is sufficient; original WordNet source files need not be part of execution identity if they are not read.

C4. Adding/removing/changing a dbfile changes model identity, while relocating an identical model tree to another filesystem root does not.

C5. Dynamic model re-hashing means a lazy external engine can detect model drift between schema/catalog discovery and first materialisation.

C6. Fresh analyzer construction per provider execution eliminates cross-materialisation mutable analyzer state as a determinism dependency.

C7. The recovered analyzer's deterministic fixture remains per-document order-independent under A→B versus B→A analysis.

C8. `BAG_UNORDERED` is correct for independent documents; `ORDERED` is available and identity-bearing when caller-visible document order is semantically significant.

C9. Document-internal token/sentence order remains preserved even when the outer document relation is `BAG_UNORDERED`.

C10. The 19-column target-hit relation is sufficient to audit why a target hit was emitted without reparsing trace prose.

C11. `MATCH_BASIS` can be derived faithfully from the recovered target-probe order without modifying the salvaged Librarian core.

C12. `RAW_TEXT`, `CLEAN_TEXT`, `RESOLVED_KEY`, resolution source/confidence, source seed and expansion rule are distinct evidence dimensions and should not be collapsed.

C13. Target weights remain preference/evidence values and cannot become authority merely by entering a table-fed pipeline.

C14. The mechanical salvage delta remains exactly reproducible despite the new adapter/manifest code around it.

C15. The remaining reviewed `RC` locals in dormant service/queue code do not create an Algorithm Relation determinism hazard; any expansion of that surface should fail the audit.

## Required adversarial areas

Provide at least **35 concrete adversarial cases** and **25 mutants**, including:

- mutate data.noun after catalog but before SELECT;
- replace one exception file with same byte length/different content;
- add/remove/rename a dbfile;
- same dbfile content under a different basename;
- identical whole model under a different absolute root;
- target file change after external-engine registration;
- gazetteer file change after registration;
- cache replacement in cache-source mode;
- incomplete manifest falsely marked complete;
- caller omits a custom morphology artefact;
- caller's analyzer factory reads an undeclared environment variable;
- analyzer factory reads current time/randomness;
- analyzer factory retains a hidden process-global cache;
- two concurrent provider executions;
- order A,B versus B,A under BAG_UNORDERED;
- order A,B versus B,A under ORDERED;
- duplicate documents in BAG_UNORDERED;
- same document ID with different text;
- punctuation/case variants that collapse to the same CLEAN_TEXT;
- BasicMorphKey-only target hit;
- Soundex resolution followed by target match;
- resolved-key hit differing from clean-text hit;
- gazetteer phrase pseudo-word coordinates;
- multiple target terms for one word use;
- duplicate target expansions from different seeds;
- same target key with different source seed;
- same seed expanded by incoming versus outgoing relation;
- malformed/non-text input;
- empty document;
- target weight +1e12 mapped by explicit downstream policy to PROHIBITED;
- target weight -1e12 mapped to REQUIRED;
- attempt to use confidence as permission;
- attempt to use category name as authority;
- stale materialisation after model closure changes;
- salvage script modifies an unrelated core line;
- ordinary RESULT assignment reintroduced;
- keyed allItems regression reintroduced.

## Questions that should remain uncomfortable

1. Is fresh analyzer-per-materialisation acceptable for full WordNet performance, or should a future immutable analyzer image/snapshot be designed?
2. Does the recovered loader read any environment/process state not represented in the model manifest?
3. Is `MATCH_BASIS` inference in the adapter sufficient, or should a future clean Librarian core emit first-class match objects directly?
4. Is `BAG_UNORDERED` safe for every current Librarian mode, especially future cross-document continuity/corpus scoring?
5. Should model manifests distinguish semantic identity from provenance identity more explicitly for individual files, not only dbfile roots?
6. How should a production provider prove that a caller-built manifest is actually complete rather than merely marked complete?

## Response format

Return:

A. Executive verdict
B. Claim-by-claim table C1–C15
C. Missing model-closure inputs, if any
D. Mutable/shared-state attack findings
E. Ordering/canonicalisation attack findings
F. Target-hit provenance attack findings
G. 35+ adversarial cases
H. 25+ mutants
I. Production blockers / should-do-next / defer
J. Any proposed contract changes in machine-testable language

