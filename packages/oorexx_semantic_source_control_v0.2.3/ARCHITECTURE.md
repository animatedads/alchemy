# Architecture — Semantic Source Control v0.2.3

## Principle

Repository truth is a graph of semantic source entities, revisions, requirements, use evidence and reviewer decisions. Files and ZIPs are carriers and lossless evidence; they are not the conceptual version model.

```text
SourceSnapshot(component, lineage, sourceLevel)
 |
 +-- SourceFileRevision ------------> SHA-256 blob (all release files)
 +-- SourcePackageRevision
 |      +-- ::options contract
 |      +-- ::requires contract
 +-- SourceClassRevision
 +-- SourceMethodRevision
 +-- SourceAttributeRevision
 |      +-- getter contract/body revision
 |      +-- setter contract/body revision
 +-- SourceConstantRevision
 +-- SourceRequirement (AT_LEAST)
 +-- SourceUse
 |      +-- CONSTRUCTOR
 |      +-- LITERAL_CLASS_MESSAGE
 |      +-- SELF_MESSAGE
 |      +-- SUPER_MESSAGE
 |      +-- DYNAMIC_MESSAGE
 +-- SourceDataDependency
 +-- ExternalCandidate
        |
        +---- TrackingDecision ledger
                   |
                   +-- ACCEPTED -> ExternalOperationRevision
                   +-- REJECTED -> explicit non-tracking decision
```

## Attribute and constant semantics

`::attribute` is an OO surface in its own right. A conceptual attribute entity aggregates its getter and setter sides rather than manufacturing unrelated methods:

```text
SourceAttributeRevision
    stable attribute identity
    scope (INSTANCE / CLASS)
    getter contract + implementation hash
    setter contract + implementation hash
```

A bare `::attribute value` creates both generated accessors. Explicit `::attribute value get` and `::attribute value set` directives may carry executable bodies; those bodies are separately hashed and their message/external-operation evidence is attributed to the corresponding accessor. Removing an existing getter or setter is a contract break; adding a previously absent accessor is an expansion.

`::constant` becomes `SourceConstantRevision` with stable class/name identity and a value hash. Value changes remain visible even when every class/method body is unchanged. API/protocol/release/version/schema/format/magic-named constants are conservatively elevated because they commonly define inter-component identities.

Attribute/constant semantics are derived indexes over immutable source blobs. Older accepted snapshots are re-indexed in memory under the current analyzer; their source bytes and accepted source levels are never rewritten.

## Batched SHA-256 identity

Repository identity remains SHA-256. v0.2.2 changes *how* normal tree analysis obtains those digests: a side-effect-free warm-up pass registers all unique file/entity/contract/body payloads, one batched SHA-256 invocation hashes them, and the authoritative pass consumes the in-memory digest cache. This removes per-entity subprocess creation while retaining the same digest algorithm and content-addressed blob layout. Isolated API hashing outside an analyzer batch retains a fallback path.

## Entity identity versus revision

An `entityId` identifies the conceptual object through history. A `revisionId` identifies one historical contract/body revision. Paths remain source-location evidence rather than class/method identity.

A method rename can therefore remain one historical entity when body and contract evidence supports it. A file move does not itself create semantic change.


## External-operation classification and relocation

External-operation detection is deliberately a proposal layer over ordinary Rexx parsing. Host-language syntax must not itself manufacture an external operation. In particular, Rexx `CALL foo ...` is a routine invocation, not SQL `CALL`; SQL stored-procedure `CALL` is recognised only where it is visibly carried as SQL text or follows `EXEC SQL`.

An accepted `ExternalOperation` has identity independent of its current containing method, but relocation is reconciled as a **set**, not candidate-by-candidate. Resolution order is:

1. exact historical proposal/decision;
2. continuity against the immediately previous accepted external-operation call-site;
3. same-method contextual evidence where it is one-to-one;
4. cross-method relocation only when one remaining candidate and one remaining historical identity are each other's sole compatible partner;
5. otherwise, create a new proposal.

An external identity may map to at most one current call-site. Same SQL operation/table is therefore only compatibility evidence. If the old transfer INSERT still exists and FX introduces another INSERT into the same table, the old transfer keeps its identity and FX is proposed as new. This preserves legitimate method extraction without conflating independent durability boundaries.

## Lightweight historical identity views

Baseline adoption does not require the entire historical semantic graph. `latestIdentityView` reads persisted class/method/attribute/constant/external-candidate evidence directly from `snapshot.osc`, recursively reconstructs accepted external-operation continuity, and caches that compact view for the command lifecycle. It intentionally does **not** invoke legacy blob re-indexing.

Full `loadSnapshot` remains the richer path for impact, historical source reconstruction and export. This separation prevents a large pre-schema repository from being semantically re-analyzed several times merely to adopt its next source level. Tracking-decision writes invalidate derived identity caches; immutable accepted source rows remain untouched.

## Batched contextual MD5

The contextual call-site fingerprint still consists of MD5s of normalized statement/context lines as originally designed. Tree analysis collects those MD5 payloads and hashes them in one batch. The aggregate internal anchor uses the repository SHA batch; the persisted identity evidence remains the ordered MD5 statement/before/after signatures.

## Package semantics

ooRexx package directives can change runtime/compilation meaning without touching any method body. v0.2 therefore treats package contracts as first-class source entities.

```text
SourcePackageRevision
    semantic anchor (first class/routine/package method when available)
    ::options[]
    ::requires[]
```

Examples:

```text
::options digits 30 removed
    -> PACKAGE_OPTIONS_CHANGED [HIGH]

::requires "JournalPointedState.cls" removed
    -> SOURCE_REQUIREMENT_REMOVED [MAY_BREAK]
```

The package anchor is semantic where possible, so moving a class-bearing source file does not manufacture a package change.

## Receiver-aware dependency evidence

A bare message name is not enough in an OO language. v0.2 records the receiver evidence visible in source:

```text
.IBM4361Machine~new(...)
    -> SourceUse(message=init,
                 kind=CONSTRUCTOR,
                 targetClass=IBM4361Machine)

.SomeClass~foo(...)
    -> LITERAL_CLASS_MESSAGE(SomeClass.foo)

self~foo(...)
    -> SELF_MESSAGE(current class)

self~init:super
    -> SUPER_MESSAGE

someVariable~foo(...)
    -> DYNAMIC_MESSAGE
```

Exact receiver evidence can yield `MAY_BREAK`. Unknown receiver type is retained as lower-confidence `VERIFICATION_REQUIRED` rather than being falsely asserted as an exact consumer. `SUPER_MESSAGE` is not globally matched merely because its message token happens to be `init`.

Executable code at package scope is analyzed too. This matters particularly for ooRexx test scripts, which often construct objects before their trailing `::requires` directives.

## Source levels

`sourceLevel` is a monotonically meaningful whole number inside a `lineage`. Consumer knowledge is expressed as:

```text
KnownSourceRequirement
    target   DataStore.AccountStore.loadAccounts
    relation AT_LEAST
    minimum  7
```

A higher level does not automatically prove compatibility. Contract changes and requirement satisfaction are evaluated independently. Different lineages are not numerically comparable.

## External-operation identity

Detection proposes, rather than silently creates, an independently tracked operation. A candidate fingerprint contains:

```text
containing method/package entity
beforeContextMD5[]
statementMD5
afterContextMD5[]
semantic contract
```

The MD5s are relocation/change fingerprints, not security digests. Accepted operations receive stable `EO-...` identity. Rejections remain durable knowledge; materially changed candidates can be proposed again.

## SQL semantic contract

Tracked SQL carries bounded semantics:

```text
operation
sources
projection/order
write columns
predicate
```

Host ooRexx string/call delimiters are removed before SQL semantic comparison. Deltas include projection/order, source, operation, write-column and predicate-scope changes and can propagate through declared result-ordinal/data-lineage edges.

## Immutable semantic history, evolving knowledge

Accepted source levels are immutable. Reviewer knowledge is append-only and separate:

```text
source level 17 snapshot
      |
      +-- candidate TP-123 (immutable source evidence)

later: TP-123 REJECTED
later: TP-123 ACCEPTED (supersedes rejection)
```

Learning what old source means does not rewrite the old source.

## Whole-release evidence

v0.2 stores every file under the baseline root as an immutable SHA-256 blob. Only `.cls`/`.rex` files are currently semantically parsed; every other file is still release evidence and is reconstructed by `osc export`.

This deliberately separates:

```text
semantic identity / impact model
        from
lossless release reconstruction
```

A schema file can therefore be retained even before a dedicated SQL-schema entity model exists.

## Scaling law

Large snapshot assembly must not repeatedly concatenate immutable Rexx strings or spawn one digest process per entity. Shared list-to-string construction uses `MutableBuffer`, accepted-snapshot equality is linear, contextual MD5s are created only at suspected external call-sites, and SHA-256 entity/blob inputs are batch-hashed before the authoritative semantic pass.

## Backward compatibility

v0.2 reads v0.1 snapshot records. New v0.2 record kinds (`K` package contracts and richer `U` use evidence) are added only to new source levels. Existing accepted v0.1 levels are not rewritten or migrated in place.

## v0.2 lexical and OO-side identity rules

Structural analysis uses a comment-aware lexical view of each physical source line. Block comments may span and nest across lines; comment delimiters inside quoted strings remain ordinary characters. The lexical view is used for package/class/method discovery, message-use evidence and external-operation proposals while original byte streams remain immutable blob evidence.

Method side is part of semantic identity. Instance-side keys intentionally keep the v0.1 spelling (`Component.Class.message`) so existing repositories and external-operation decisions remain usable. Class-side keys are `Component.Class.message#CLASS`; receiver-specific live trial implementations reserve `#OBJECT`. A class literal `.C~message` is class-side evidence, while `.C~new(...)` is an explicit dependency on the instance-side `C.init` contract.

A v0.1 accepted snapshot may lack semantic indexes introduced in v0.2. The repository can re-index its immutable historical source blobs into a current in-memory semantic view and then re-apply the append-only tracking decisions. This is a derived interpretation upgrade, not a rewrite of accepted source history.
