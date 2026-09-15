# Structured Relation -> HardWorld Rich Evidence bridge v0.16

## Purpose

The structured-source lane already owns rich native XML, UN/EDIFACT, X12, Git and GitHub source models. v0.16 does not reimplement those parsers. It establishes the receiving contract by which a `RichBusinessFact` can become HardWorld/Algorithm Relation evidence without losing the source graph.

## Source-side contract consumed

The bridge expects a fact exposing:

```text
name
value
state
semanticType
lexicalValue
source
row
diagnostics
annotations
createdAt
sourceProvenance()
sourceDocument()
sourcePath()
processingHistory()
```

This deliberately avoids a compile-time class dependency on `structured_relation_plugin`. Source ownership stays with the source package.

## Preserved objects

For each fact, v0.16 retains:

- native source node / attribute / EDI element / other source object;
- source document reachable through that source object;
- original `RichBusinessFact`;
- original projected row;
- native processing-event objects;
- native diagnostic objects;
- copied frozen annotation values;
- native source path and structural kind;
- lexical and typed scalar evidence where safely projectable.

`RichEvidenceValue~contexts()` exposes projection-context records. `processingHistory()` and `diagnostics()` now return retained evidence records rather than flattened display strings.

## Deterministic identity versus runtime provenance

Runtime objects remain reachable, but they are not used by arbitrary string representation.

Canonical identity uses explicit fields:

```text
source format
source kind
source path
source document source + parser + SHA-256(bytes)
line / column where available
bridge / transform identity
lexical value
typed scalar value
validation state
fact semantic type / evidence state
relation/projection name
annotations
structured processing phase/operation/detail
structured diagnostic severity/code/message/validator/details
consistency grade/hash
```

Wall-clock processing timestamps and `RichBusinessFact.createdAt` remain reachable provenance but are excluded from semantic identity. Re-parsing identical bytes through the same mapping therefore retains deterministic evidence identity.

## No implicit stringification

The internal regression supplies a source object and processing-event object whose `STRING` methods raise errors. The complete bridge and hashing path succeeds.

`RICH_OBJECT` is still not a NoSQL/MySQL scalar type. Direct exposure is refused. The explicit `RichBusinessFactAlgorithmProvider` projects only declared scalar summary/provenance columns.

## Evidence-set combination

`StructuredRelationRichEvidenceAdapter~combineFacts()` combines several format-specific facts under an explicit semantic role.

The input facts are canonicalised by evidence identity before combination, so source arrival order does not decide output identity.

Current scalar semantics:

```text
all sources scalar + same value
    -> PRESENT / SCALAR_AVAILABLE

all sources scalar + different values
    -> CONFLICT / SCALAR_REFUSED

any source non-scalar / invalid
    -> UNRESOLVED / SCALAR_REFUSED
```

Multiplicity and provenance remain separate sources.

The supplied fixtures provide a real plumbing specimen:

```text
XML /o:.../Line[2]/c:Quantity = 50
X12 PO1/2                     = 2
```

v0.16 emits conflict rather than choosing 50, choosing 2, or producing `"50,2"`.

## HardWorld promotion boundary

The adapter never calls `putKnown()` and never assigns `REQUIRED`, `PROHIBITED`, `PERMITTED`, etc.

The test explicitly demonstrates a caller/policy promotion:

```text
world~putKnown(...,
               source='TEST_ONLY_STRUCTURED_PROMOTION',
               authority='TEST_POLICY',
               evidence=xmlRich)
```

That visible promotion is intentionally separate from evidence adaptation.

## Current non-claims

- v0.16 does not own XML/EDI/X12 parsing.
- it does not cryptographically attest the structured-source adapter package;
- it does not infer semantic equivalence between fields from different formats;
- `combineFacts()` only combines facts the caller explicitly says share a semantic role;
- caller-supplied consistency grades remain subject to the v0.14 attestation model;
- native object lifetime is owned by the source package;
- SQL projection is intentionally lossy and cannot reconstruct the full source graph.
