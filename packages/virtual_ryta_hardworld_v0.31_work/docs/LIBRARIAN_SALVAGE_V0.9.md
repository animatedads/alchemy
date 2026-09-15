# Librarian salvage and Algorithm Relation integration — v0.9

## Source provenance

The supplied surviving monolithic Librarian is retained without modification as:

`librarian/source/librarian_wordnet_oorexx.rex.original`

SHA-256:

`cfaf24c475f99008388f58cd2b43ba900deaad24af286a6e264fb2684045ac5e`

The source is an executable program and class package in one file. Requiring it as a class library also executes its command-line bootstrap. v0.9 therefore derives a class-only package rather than editing the archived source.

## Declared salvage delta

`librarian/LibrarianCore.cls` is produced from the source by exactly these changes:

1. Remove source lines 1–12: shebang/comments plus the executable `parse arg` / `LibrarianEngine~run` bootstrap.
2. Repair 11 keyed native ooRexx `.Relation` lookups from `allItems(key)` to `allAt(key)`. On ooRexx 5.3.0 r13196, `allItems` takes no key; `allAt(index)` returns all relation items at an index.
3. Rename the local `result` array in `LibrarianRelationGraph~expand` to `expandedWords`.
4. Rename the local `result` string in `MergeWordLists` to `mergedWords`.

The last two changes avoid the ooRexx special `RESULT` variable hazard across message/function calls.

`tests/test_librarian_salvage_delta.py` reproduces the transformation and requires byte-for-byte equality with `LibrarianCore.cls`. Changes outside this declared delta fail the test.

## Destructive-operation forensic check

The supplied Librarian engine contains queue/cache/file IO and optional RexxUtil directory scanning. The forensic scan used for v0.9 found no `ADDRESS SYSTEM`, shell `rm`, mount/remount/umount, `/dev/null`, or shell `mv` path in the Librarian engine. No claim is made about the surrounding historical Alchemy application from which the README was recovered.

## Preserved deterministic surfaces

The integration uses the surviving public object model rather than parsing printed output:

- `LibrarianAnalyzer`
- `LibrarianArticle`
- `LibrarianParagraph`
- `LibrarianSentence`
- `LibrarianWordUse`
- `LibrarianTargetModel`
- lexical resolver / grammar / gazetteer / relation graph

The provider emits six typed relations:

- `LIBRARIAN_DOCUMENT_ANALYSIS`
- `LIBRARIAN_SENTENCE_ANALYSIS`
- `LIBRARIAN_WORD_OBSERVATIONS`
- `LIBRARIAN_TARGET_HITS`
- `LIBRARIAN_ANALYSIS_ERRORS`
- `LIBRARIAN_TRACE`

## Authority boundary

Librarian outputs evidence and categorisation. It does not emit HardWorld `KNOWN_TRUE`, `REQUIRED`, `PROHIBITED`, approval or authority values.

Any future promotion such as:

`Librarian target hit -> HardWorld fact`

must be an explicit reviewed mapping with source, authority, epistemic treatment and conflict semantics. v0.9 deliberately refuses to invent that policy.

## Test fixture versus real Librarian model

`LibrarianDeterministicFixture.cls` is a tiny test-only lexicon/target model so the adapter can be validated without shipping a WordNet corpus. It is not presented as a replacement for Librarian's real WordNet model.

The production-style provider accepts a caller-supplied `LibrarianAnalyzer` plus explicit model ID/version/fingerprint. The model fingerprint participates in the Algorithm Relation source manifest and materialisation identity.

A real deployment fingerprint should cover, as applicable:

- WordNet data/version or cache;
- relation graph inputs;
- exception and alias data;
- target/topic definitions;
- gazetteer definitions;
- grammar/model code version;
- any other mutable lookup state that can change analysis output.

## Live v0.9 pipeline

On stock NoSQLServer v0.68:

```text
frozen text relation
    -> Librarian (1 execution)
    -> librarian_hits
    -> persisted explicit toy policy join
    -> frozen SQL relation
    -> TABLE_FEED_DECIDER (1 execution)
    -> librarian_decisions
```

The sample demonstrates that target weights remain preference/evidence values and do not defeat explicit downstream authority dispositions.
