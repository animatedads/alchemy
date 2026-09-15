# Virtual RYTA / HardWorld v0.11 — Librarian closure adversarial review

## Role

Attack v0.11. Assume the goal is to disprove `same materialisation identity -> same Librarian evidence`.

Do **not** compensate for Librarian evidence defects by granting Librarian authority or weakening HardWorld. Librarian remains evidence only.

## v0.11 blocker repairs

The v0.11 candidate responds directly to the adversarial findings that identified Soundex crash, live model mutation, POS leakage, superlinear denormalized output, cache-order semantic drift, duplicate-target ambiguity, lost multipath provenance, incomplete selected-sense/Soundex evidence and lossy canonicalization visibility.

It now provides:

1. Soundex/EditDistance regression repair.
2. Artefact closure + object closure contract.
3. Fresh frozen analyzer per provider execution.
4. Deep model freeze including get-only component references and immutable leaf model records.
5. POS-constrained target matching without synthetic `/ANY` bypass.
6. Cache v2 canonical serialization with stable sense order.
7. Conflicting duplicate target declarations are model errors.
8. `INPUT_ROW_ORDINAL` on normalized evidence rows.
9. Separate score contribution and multipath target provenance relations.
10. Selected sense offset/category/source columns.
11. `LIBRARIAN_RESOLUTION_CANDIDATES` for Soundex evidence.
12. Separate raw/normalized/canonical/compact surfaces and match basis.
13. Ingress/result limits; no unbounded denormalized TARGET_HITS output.
14. Manifest membership frozen at publication while declared files are rehashed live.
15. Mechanical v0.9 salvage checkpoint retained separately from the intentional v0.11 hardened derivative.
16. Librarian test assertion failures now raise and fail the process rather than printing a false-red/false-green line.

## Claims to attack

C1. The recovered Soundex path cannot crash on valid text solely because EditDistance uses a compound tail expression.

C2. A published v0.11 factory/provider cannot mutate or replace any output-affecting resident model object without changing/reconstructing model identity.

C3. Manifest membership cannot change after publication, while content drift of any declared file remains detectable before lazy first materialisation.

C4. The machine-readable closure contract enumerates every output-affecting model family used by the recovered direct loader or cache mode.

C5. Fresh analyzer-per-execution removes cross-materialisation analyzer mutation/order as hidden state.

C6. A POS-constrained target does not match a word use whose resolved/role POS is incompatible merely through an ANY index.

C7. Cache v2 round-trip preserves primary sense, exception mapping and relation-edge semantics and repeated saves are canonical.

C8. Conflicting duplicate target declarations cannot silently first-win.

C9. Duplicate input relation rows retain bag multiplicity **and** distinct input-row provenance.

C10. One target score contribution can retain multiple expansion provenance paths without multiplying the score.

C11. Selected sense identity is available relationally without reparsing trace text.

C12. Soundex candidate competition is available relationally without reparsing trace text.

C13. Lossy canonicalization is visible through distinct surface/key/source fields rather than being labelled indistinguishably as raw exact spelling.

C14. All-invalid oversized input is rejected before an analyzer is constructed.

C15. Output-size limits cover observations, score-hit rows, multipath provenance rows and resolution-candidate rows.

C16. Removal of unbounded denormalized TARGET_HITS fields eliminates the repeated growing-string output surface without losing normalized evidence.

C17. The old recovered source remains byte-identical and the v0.9 mechanical salvage checkpoint is still exactly reproducible.

C18. `LibrarianCore.cls` is explicitly a reviewed hardened derivative rather than being falsely represented as a purely mechanical salvage.

C19. Test assertions in the Librarian lane actually fail the Rexx process when false.

C20. None of these repairs promote Librarian score/category/confidence into HardWorld authority.

## Required attacks

Return at least **45 concrete adversarial cases** and **30 mutants**. Include at minimum:

- mutate every declared artefact after metadata but before first SELECT;
- add/remove a dbfile after manifest publication;
- replace a declared file atomically under the same path;
- mutate a target model through every public method after freeze;
- replace lexicon/graph/grammar references after freeze;
- mutate a returned senses/terms collection;
- mutate a leaf sense/target/edge/gazetteer record;
- attempt factory rebinding to another manifest;
- hidden factory state not represented by the closure hash;
- environment/time/random/process-global state in a custom factory;
- concurrent provider executions with separate analyzers;
- concurrent reads of one lazy materialisation;
- Soundex tie candidates in different insertion orders;
- 0/1/2 edit-distance boundaries;
- very large Soundex bucket;
- target N versus observed V and vice versa;
- target ANY versus every observed POS;
- role POS contradicting resolved POS;
- same target declaration same weight repeated;
- same target declaration conflicting weights;
- same target reached by 2/10/100 graph paths;
- same contribution reached from distinct seeds;
- duplicate identical input documents;
- same DOCUMENT_ID with different text;
- BAG_UNORDERED permutation;
- ORDERED permutation;
- cache save/load across different insertion orders;
- cache exceptions and graph edges in random insertion order;
- source-loaded versus cache-loaded resolution output comparison;
- accented Latin, combining marks, non-Latin Unicode, embedded NUL, punctuation obfuscation;
- surface string that collapses to empty canonical key;
- 4095/4096/4097 token boundaries;
- byte-boundary inputs with multibyte UTF-8;
- 99/100/101 documents;
- observation/hit/provenance/candidate exact-limit boundaries;
- malformed row plus valid row in same invocation;
- all rows invalid and prove analyzer factory build count remains zero;
- trace relation growth under rejected input;
- intentionally false assertion and prove runner fails non-zero;
- stale old v0.9 relation-count/schema assertions;
- mutate the original recovered source and prove salvage hash fails;
- mutate the v0.9 mechanical checkpoint and prove salvage test fails;
- reintroduce `curr.(j-1)`;
- reintroduce constrained-term `/ANY` indexing;
- reintroduce ordinary RESULT local;
- reintroduce keyed `allItems(key)`;
- permit score +1e12 to override PROHIBITED downstream;
- permit score -1e12 to defeat REQUIRED downstream.

## Model-closure question

Provide a table with columns:

```text
OBJECT_OR_ARTEFACT
OUTPUT_AFFECTING
CURRENTLY_HASHED
CURRENTLY_FROZEN
MUTATION_PATH
IDENTITY_CHANGE_GUARANTEED
MISSING_TEST
```

Walk the complete closure, not only the classes mentioned in this brief.

## Required response

A. Executive verdict
B. C1-C20 claim table
C. Full model-closure table
D. Mutable-state escape paths
E. Cache/source equivalence findings
F. Canonicalization/Unicode findings
G. Resource-exhaustion findings
H. 45+ adversarial cases
I. 30+ mutants
J. Production blockers / should-do-next / defer
K. Proposed machine-testable contract changes
