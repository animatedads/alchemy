# Librarian v0.11 model closure and freeze contract

## Purpose

For Librarian to advertise `DETERMINISTIC_GIVEN_MATERIALIZED_INPUT`, the following implication must be mechanically defensible:

```text
same algorithm/source identity
+ same model closure identity
+ same immutable input snapshot
+ same invocation contract
=
same typed evidence relations
```

v0.11 therefore separates **artefact closure** from **object closure**. A complete file manifest without an immutable in-memory model is insufficient; a frozen in-memory model constructed from incompletely identified artefacts is also insufficient.

The machine-readable declaration is `librarian/LibrarianModelClosureContract.cls`.

## Artefact closure

The direct recovered WordNet loader model comprises, according to the loader path actually present in the salvaged code:

- `data.noun`
- `data.verb`
- `data.adj`
- `data.adv`
- `noun.exc`
- `verb.exc`
- `adj.exc`
- `adv.exc`
- dbfiles directory membership, **basename**, and contents when dbfiles are enabled
- target definitions
- external gazetteer definitions, or the explicitly declared built-in-gazetteer mode
- analyzer configuration

For cache-source mode, the cache file replaces the source WordNet artefacts that are not read during execution. Targets, gazetteer and analyzer configuration remain separate identity-bearing artefacts when used.

Absolute filesystem path is provenance, not semantic model identity. dbfile basename is semantic identity because the recovered loader uses the filename as a relation/category name.

Manifest **membership freezes at publication**. File content remains live-rehashed so drift between metadata discovery and lazy first materialisation is detectable.

## Object closure

Before an analyzer is supplied to a provider execution, these output-affecting objects are frozen:

```text
LibrarianAnalyzer
  -> LibrarianLexicon
       -> LibrarianWord
            -> ordered LibrarianSense objects
       -> exceptions
       -> Soundex index
  -> LibrarianRelationGraph
       -> immutable LibrarianRelationEdge objects
  -> LibrarianGrammar
  -> LibrarianResolver
       -> get-only lexicon/grammar references
  -> LibrarianTargetModel
       -> immutable LibrarianTargetSeed objects
       -> immutable LibrarianTargetTerm objects
       -> get-only lexicon/graph references
  -> LibrarianGazetteer
       -> immutable LibrarianGazetteerEntry objects
       -> get-only lexicon reference
```

Collection accessors that participate in the published model return copies rather than backing collections where they are exposed. Leaf model objects use get-only attributes.

After freeze, model-building operations such as sense insertion, exception insertion, graph linking, Soundex rebuilding, grammar extension, target loading/expansion, and gazetteer insertion fail. Replacing component references is also unavailable through setters.

A semantic model change therefore requires construction of a new model/factory closure and consequently a new identity.

## Analyzer lifetime

v0.11 deliberately uses:

```text
fresh frozen LibrarianAnalyzer per provider execution
```

rather than a resident/shared analyzer. This is conservative and may cost model-load time for a full WordNet deployment. A future resident/pool mode must prove an `IMMUTABLE_MODEL_SNAPSHOT` contract plus concurrency/order tests before it can advertise the same determinism class.

## Cache equivalence

Cache format v2 uses canonical serialization:

- words: canonical serialized row order;
- senses: original stable sense ID/order, not `.Table` supplier order;
- exceptions: canonical serialized row order;
- relation edges: canonical serialized row order.

The regression suite verifies primary-sense preservation, exception mapping preservation, edge preservation and byte-identical repeated cache saves.

## Input/output bounds

Before analyzer construction, the provider preflights:

- documents per invocation;
- bytes per document;
- tokens per document.

During result construction it bounds:

- word observations;
- scoring target hits;
- target-hit provenance rows;
- resolution candidate rows.

The limits are identity-bearing provider configuration. Unbounded document/sentence `TARGET_HITS` prose aggregates are not emitted; normalized relations carry the complete evidence.

## Evidence provenance

v0.11 separates scoring multiplicity from provenance multiplicity.

One target contribution can add its weight once while `LIBRARIAN_TARGET_HIT_PROVENANCE` retains multiple expansion paths. `LIBRARIAN_RESOLUTION_CANDIDATES` records Soundex candidate competition. Selected-sense offset/category/source and duplicate input-row ordinal are first-class columns.

Surface/canonical evidence is exposed separately:

```text
RAW_TEXT
NORMALISED_SURFACE
CLEAN_TEXT
COMPACT_MATCH_KEY
RESOLUTION_SOURCE
MATCH_BASIS
```

Thus a lossy canonicalization such as an accented or punctuated surface collapsing to an ASCII key is visible rather than being indistinguishable from an ordinary raw exact spelling.

## Deliberate non-claim

The supplied Librarian bundle does not contain a complete real WordNet deployment tree. The closure builder is exercised against synthetic artefacts matching the recovered loader contract. A real deployed model tree must still be run through this closure and acceptance suite before production freeze is claimed.
