# Librarian hardening v0.10

## Scope

v0.10 responds to the adversarial review of the v0.9 Librarian Algorithm Relation. It does not redesign the salvaged Librarian engine and does not promote lexical evidence into HardWorld authority.

The original recovered source remains byte-preserved. `LibrarianCore.cls` remains the mechanically reproduced v0.9 salvage transform: bootstrap removal, 11 keyed Relation API repairs (`allItems(key)` -> `allAt(key)`), and two ordinary `result` local renames. `test_librarian_salvage_delta.py` still reconstructs and byte-compares that transform.

## 1. Full model-closure identity

`librarian/LibrarianModelManifest.cls` introduces an explicit model closure.

A production-complete Librarian provider now requires a model manifest in `FILE_HASHED_COMPLETE` mode. The provider no longer treats one source-file SHA as adequate model identity.

The model manifest supports:

- individual file artefacts;
- directory membership + content (used for `dbfiles`);
- logical/configuration artefacts;
- dynamic re-hashing through `currentHash`.

`LibrarianWordNetModelManifestBuilder` covers the recovered loader's model inputs:

- `data.noun`, `data.verb`, `data.adj`, `data.adv`;
- `noun.exc`, `verb.exc`, `adj.exc`, `adv.exc`;
- all current files under `dbfiles` when enabled;
- target definitions;
- external gazetteer definitions when supplied;
- a resident lexicon cache when cache-loading is selected;
- declared analyzer configuration.

The dbfile **basename** participates in identity because Librarian uses it as a relation category. The absolute filesystem root does not participate, so identical model trees copied to different mount points hash identically.

The fixture model has its own complete manifest over the fixture code, salvaged Librarian core, target file, and canonical synthetic senses/configuration.

### Lazy drift detection

The model manifest retains file/directory locations and re-hashes them when identity is requested. `LibrarianTextAlgorithmProvider~sourceManifestHash` incorporates the current model-closure hash.

Therefore a lazy NoSQL external engine can detect a target/WordNet/gazetteer/cache change between metadata registration and first row materialisation. The live v0.68 test mutates a target file after external-engine construction and receives:

`SOURCE_MANIFEST_CHANGED_BEFORE_MATERIALIZATION`

with provider invocation count still zero.

## 2. Analyzer isolation

v0.9 accepted a resident `LibrarianAnalyzer` object. v0.10 accepts an analyzer factory.

Each provider execution calls `newAnalyzer` exactly once and uses that analyzer only for that materialisation. A later materialisation receives a fresh analyzer.

This intentionally favours deterministic isolation over performance. A future resident/pool implementation must provide a separately tested immutable-model-snapshot contract rather than silently restoring shared mutable analyzer state.

The order/isolation test additionally analyses A then B and B then A using the surviving analyzer itself. Per-document article score, target score, and concepts remain identical in the deterministic fixture.

## 3. Explicit relation-order semantics

The Librarian input contract now states:

`ORDER_MODE=EXPLICIT;BAG_UNORDERED=INDEPENDENT_DOCUMENTS;ORDERED=CALLER_SEQUENCE`

For independent document bags, `BAG_UNORDERED` canonicalises document row order before hashing and before provider analysis. Duplicate rows remain duplicates.

For caller-declared sequence-sensitive workloads, `ORDERED` preserves row sequence and makes it part of content identity.

Text **inside each document** is always sequence-bearing; sentence and word coordinates preserve that internal order.

## 4. Structured target-hit provenance

`LIBRARIAN_TARGET_HITS` is expanded from the v0.9 compact hit row to a 19-column evidence relation:

- `INVOCATION_ID`
- `DOCUMENT_ID`
- `PARAGRAPH_NO`
- `SENTENCE_NO`
- `WORD_NO`
- `COORDINATE`
- `RAW_TEXT` (original surface form)
- `CLEAN_TEXT` (canonicalised token form)
- `RESOLVED_KEY`
- `RESOLVED_POS`
- `RESOLUTION_SOURCE`
- `CONFIDENCE`
- `MATCH_BASIS`
- `SECTION`
- `TARGET_KEY`
- `TARGET_POS`
- `WEIGHT`
- `SOURCE_SEED`
- `EXPANSION_RULE`

No downstream consumer needs to parse `LIBRARIAN_TRACE` prose or split the coordinate string to identify the source word or the target-expansion provenance.

`MATCH_BASIS` records which deterministic probe surface explains the term match (`CLEAN_TEXT`, `RESOLVED_KEY`, `BASIC_MORPH`, etc.).

## 5. Salvage special-variable audit

The v0.9 `RESULT` hazard repair remains frozen.

`test_librarian_special_variable_audit.py` now additionally guards the salvage against:

- new ordinary `RESULT/result` assignments;
- ordinary `SIGL` assignments;
- keyed `allItems(...)` regressions;
- growth/change of the small reviewed `RC` assignment surface in the old resident-service/queue code.

The remaining RC assignments are immediate service/queue status captures. They are not used by the Algorithm Relation provider, and their exact forms are frozen for review rather than silently renamed in the salvaged engine.

## Authority boundary remains unchanged

Librarian output is evidence and categorisation.

`TARGET_SCORE`, target weights, lexical scores, Soundex fallback, or expansion provenance do **not** produce HardWorld `REQUIRED`, `PROHIBITED`, or other authority dispositions.

The reference pipeline still uses an explicit SQL/persisted policy relation before a downstream decision algorithm applies authority.

