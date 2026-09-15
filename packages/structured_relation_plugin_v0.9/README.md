# Structured Relation Plugin v0.9

Pure-ooRexx structured source/evidence adapters for NoSQLServer, DB relation work and HardWorld-style
rules. The invariant remains: **preserve the native information object first; project later**.

v0.9 contains four source/evidence families:

- XML + namespace-aware XPath subset + structured validation + bounded native XSLT-style transforms;
- UN/EDIFACT with interchange/message/segment/element/repetition/component identity;
- X12 with interchange/group/transaction/segment/element/repetition/component identity;
- Git + GitHub + bounded C/C++ semantic evidence with commit/file/blob/span/diff/PR/review/symbol/guard/CFG/value-origin/alias/ownership identities.

The XML/EDI and semantic model are pure ooRexx. The Git adapter invokes the installed `git` executable as
the Git object-database interface, but human-readable command output is not retained as the internal model.
Machine-oriented Git data is immediately reified into ooRexx objects.

## v0.6 semantic source model

`CodeSemanticSource.cls` adds a deliberately bounded C/C++ semantic layer over an exact
`GitFileRevision` or blob-bound public source revision:

```text
CodeSemanticDocument
  -> CodeSymbolRevision
       -> CodeGuardNode
       -> CodeCallNode
       -> CodeReturnNode
       -> CodeValueOrigin
       -> CodeControlFlowGraph
            -> CodeControlFlowEdge
```

Every syntax object points back to a revision-bound source span.  A function is not merely a name and a
memory operation is not merely the token `memcpy`: the objects retain the exact blob/revision, source
span, arguments, dominating guard, modelled destination extent and parameter/value origins.

The analyser is intentionally *not* advertised as a complete C++ compiler.  v0.6 understands a useful
subset sufficient to establish evidence such as:

- the predecessor write was dominated by `len <= 64`;
- the successor write is still dominated by the same guard;
- the copy API changed from byte-count to range semantics;
- a length expression originates in a function parameter;
- a local allocation is released, returned as ownership transfer, or remains unresolved in the bounded
  model.

The limitations are carried into findings instead of silently becoming certainty.


## v0.7 value and ownership flow

`CodeValueFlow.cls` enriches a `CodeSymbolRevision` without replacing its source-bound syntax objects:

```text
CodeSymbolRevision
  -> CodeValueFlowGraph
       -> CodeValueFlowEdge
            EXACT_ALIAS
            DERIVED_EXPRESSION
       -> CodeGuardConstraint
       -> CodeCallFlowFact
```

An exact alias such as `size_t n = len` is deliberately different from a derived value such as
`size_t n = len + 1`.  A bounds guard is credited to a memory operation only when the guarded subject is
exactly equivalent to the value used as the modelled copy length, the guard dominates the operation, and
where a fixed destination extent is known the normalized upper bound fits that extent.  Therefore a nearby
`if (other <= 64)` does not protect a `memcpy(..., len)`, and preserving textual `if (len <= 64)` does not
protect a successor `memcpy(..., n)` when `n = len + 1`.

`MemoryOwnershipFlowRule` likewise follows exact local aliases.  It distinguishes release through an alias,
return through an alias, an unresolved escape to another call, and a local allocation for which no such
evidence is visible.  Passing an object to an unknown call withholds a leak verdict because the bounded
model does not know whether the callee borrows, stores, releases or takes ownership.

The flow graph is evidence, not a whole-program proof: pointer arithmetic, field/global stores, macros,
exceptions, threads and interprocedural ownership contracts remain explicit limitations.

## Public corpus: Bitcoin Core

`BitcoinCorePublicCorpus.cls` remains a timestamped public evidence snapshot over `bitcoin/bitcoin`, with
PRs #35688, #31868 and #34083 retained as independent author/reviewer/measurement/CI evidence.

v0.7 retains the v0.6 exact-blob binding and additionally runs value-flow analysis over the HMAC semantic test for PR #35688. The source remains bound to the exact public base/head blobs:

- base commit `81405fc7...`, blob `0796bbeb3271a210ed7ed5d85a82fc76939db61a`;
- PR head `dc67c4cc...`, blob `d9e16f361107c6d66f32ad8050c658d3b01f9241`.

The semantic rule therefore reasons over independently checkable source identities, not a copied prose
summary.  The v0.7 flow graph also derives `keylen` as the predecessor byte-count and as the successor
range length (`key` to `key + keylen`), then proves that the same `keylen <= 64` guard constrains that value
within the retained 64-byte `rkey` extent.  PR/review explanations remain separate evidence rather than being
promoted to source truth.

## Memory-history, value-flow and ownership rules

The package now layers progressively stronger rules rather than replacing evidence with a single scanner verdict:

- `SemanticMemoryHistoryRule` distinguishes a preserved textual/dominating guard from a removed one;
- `MemoryValueFlowHistoryRule` requires that the guard constrain the value actually used as the memory length;
- `MemoryLifetimeRule` retains the earlier direct local release/return evidence;
- `MemoryOwnershipFlowRule` follows exact aliases and treats unknown-call escape as unresolved counterevidence.

Both lifetime/ownership rules deliberately emit review findings rather than “memory leak proven” when the bounded
model cannot establish whole-path ownership behavior. That uncertainty is part of the finding object.

All `CodeAnalysisFinding` objects can become `RichBusinessFact` objects for HardWorld while retaining the
semantic change/symbol object as their source.



## v0.9 EDIFACT source annotations and functional groups

The native EDIFACT model now preserves non-EDIFACT `/* ... */` annotations that appear **between** segments as
`EdiFactSourceAnnotation` objects with exact source spans. They are ignored by EDIFACT grammar but are not stripped
from the source text or provenance. This is intentionally a host/demo-source accommodation, not a claim that C-style
comments are valid UN/EDIFACT syntax. Unterminated annotations are rejected.

`UNG`/`UNE` are now retained as `EdiFactFunctionalGroup` objects. Messages and segments retain group identity, and
`@groupReference` is available on message/segment projection contexts. Envelope validation checks group message counts
and group references; where functional groups exist, `UNZ` control count is compared to groups rather than messages.

The shipped fictional OurLadyAir PNRGOV fixture deliberately contains source annotations and an invalid outer envelope.
It parses without provenance loss, reports the envelope defects instead of repairing them, and projects PNR/SSR/TIF
relations through NoSQLServer v0.73. A compound SQL join proves that only functional group `G07` carries `NSST`
(`SEAT NOT PURCHASED`) for three passengers; the demo commercial rule of EUR20 per unreserved seat therefore yields
EUR60. Scattered groups that already carry `SSR+SEAT` are not selected by that rule.

## v0.8 remote Git blob attestation

`RemoteSourceFileRevision` no longer treats a supplied blob SHA as proof.  Remote source provenance now
distinguishes:

```text
REVISION_PATH_ONLY   no blob identifier supplied
GIT_BLOB_CLAIMED     blob identifier supplied but bytes not checked
GIT_BLOB_BOUND       carried bytes verified against Git blob identity
GIT_BLOB_MISMATCH    carried bytes do not match the claimed blob identity
GIT_BLOB_UNVERIFIED  verification could not be completed
```

`verifyBlobIdentity()` asks the installed Git executable to compute the canonical Git blob object identity
for the exact bytes carried by the object.  The computed identity and verification state remain inspectable
in provenance.  A claim therefore cannot silently upgrade itself to `GIT_BLOB_BOUND`.

The embedded Bitcoin Core PR #35688 base/head source bytes are verified during construction and match the
retained public blob IDs exactly.  This strengthens revision evidence without turning Git/GitHub evidence
into legal or HardWorld authority.

## Current NoSQLServer v0.77 compatibility

NoSQLServer v0.77 metadata construction reads the neutral external-column `textMode` surface.
Structured Relation v0.9 projection columns now expose `textMode = CLASSIC` for XML, EDIFACT, X12
and source-evidence relations. This is an adapter-contract compatibility surface only: Structured
Relation does not take ownership of NoSQLServer text/query semantics, and native source objects,
lexical values, spans, diagnostics and row/fact identities are unchanged.

The existing federation smokes pass against the supplied NoSQLServer v0.77 after this addition.

## Optional NoSQL projection

The existing source-evidence relation adapter remains the explicit lossy edge. Direct provider rows keep
rich PR origins; ordinary NoSQLServer SQL receives scalar columns. NoSQLServer v0.73 and DB v0.36 are not
modified by this package.

## Run

```sh
OOREXX_ROOT=/path/to/usr/local \
NOSQLSERVER_ROOT=/path/to/nosqlserver_v0.73 \
./run_tests.sh
```

The test fixture contains C++, C and assembly plus allocation/lifetime examples and two Git revisions of a
memory-copy operation with separate author/committer identities.

See `ARCHITECTURE.md`, `PUBLIC_CORPUS.md` and `VALIDATION.txt`.
