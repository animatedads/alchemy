# Rich Evidence / HardWorld boundary — v0.15

## Purpose

v0.15 makes the information-preservation rule executable:

> Rich native source objects may cross internal Algorithm Relation / HardWorld
> boundaries.  They are not implicitly coerced to strings or SQL scalars.
> Flattening is an explicit projection operation.

The structured-source parser remains owned by its source component.  This
package does **not** implement XML, X12 or EDIFACT parsing and does not copy a
structured-source parser into HardWorld.

## Internal type

Algorithm Input Relations add:

```text
RICH_OBJECT
```

A `RICH_OBJECT` value must expose:

```text
algorithmCanonicalText()
nativeObject
```

`algorithmCanonicalText()` is the deterministic semantic/provenance identity
used by Algorithm Relation hashing.  The native object's `STRING` method is not
part of that identity contract.

`AlgorithmInputRowView` encodes rich objects from `algorithmCanonicalText()`.
It never hashes the native object's string representation.

## RichEvidenceValue

`RichEvidenceValue` freezes the fields used by deterministic consumers while
retaining the native source object by identity.

```text
nativeObject               native object remains reachable
canonicalIdentity          stable evidence identity
semanticRole               business meaning, not authority
evidenceState              PRESENT / CONFLICT / etc.
projectionState            scalar projection disposition
presentationValue          explicit scalar value, if permitted
source refs                 zero or more preserved native source references
processing history          copied evidence history
source consistency grade    consistency claimed by the rich evidence source
source consistency hash     identity of that claim
```

The native object may remain a large XML document/node, EDIFACT component,
X12 element, or another source-native object.  The evidence wrapper does not
make deterministic output depend on later mutable state of that object.

## Source references

`RichEvidenceSourceRef` carries copied provenance fields plus a direct native
object reference:

```text
source identity
source format
source kind
source path
source document identity
line / column where available
transformation identity
original lexical value
typed value
validation state
nativeObject
```

Multiple source nodes remain multiple source references.  They are not rendered
as a comma-separated list.

## Projection states

```text
SCALAR_AVAILABLE
SCALAR_REFUSED
CARDINALITY_ERROR
INVALID_SOURCE
ABSENT
```

`scalarValue()` returns `.nil` unless the state is `SCALAR_AVAILABLE`.

Therefore a two-node quantity conflict such as `50` versus `5000` is not
silently converted to one scalar merely because SQL would prefer one cell.

## Consistency dimensions

Two consistency claims are deliberately distinct:

```text
SOURCE_CONSISTENCY_GRADE / HASH
    consistency attached to the rich source fact itself

INPUT_CONSISTENCY_GRADE / HASH
    consistency of the enclosing Algorithm Input Relation capture
```

For example, a fact may have strong source provenance but be carried through a
weaker federated `FROZEN_OBSERVATION`.  The scalar evidence projection exposes
both claims rather than collapsing them.

## HardWorld fact evidence

`RYTAFact` now has an optional getter-only `evidence` reference.

Existing rule truth remains:

```text
fact name
value
epistemic state
```

Evidence does **not** automatically alter rule truth or authority.

When Virtual RYTA is used through `RYTAAlgorithmProvider`, any attached evidence
is separately included in canonical input identity through
`algorithmCanonicalText()`.  Thus:

```text
same explicit fact/value + same semantic evidence
    -> same materialisation identity

same explicit fact/value + different provenance evidence
    -> different materialisation identity
```

while the rule result may remain exactly the same.

Promotion from evidence to a HardWorld fact remains an explicit policy step.
There is no automatic mapping from `semanticRole`, source format, lexical score,
validation result or provenance to `REQUIRED`, `PROHIBITED`, or `PERMITTED`.

## Explicit SQL projection

`RichBusinessFactAlgorithmProvider` is the reference evidence-only projection.
It consumes:

```text
FACT_ID    TEXT
RICH_VALUE RICH_OBJECT
```

and emits only scalar relations:

```text
RICH_FACT_SUMMARY
RICH_FACT_SOURCES
RICH_FACT_TRACE
```

Its summary always says:

```text
AUTHORITY_DISPOSITION = EVIDENCE_ONLY
```

For ambiguous/refused evidence, `SCALAR_VALUE` remains NULL.

## SQL / NoSQL boundary

`NoSQLServerAlgorithmRelationExternalEngine~nosqlTypeFor()` intentionally maps
only:

```text
TEXT     -> VARCHAR
OID      -> VARCHAR
INTEGER  -> INTEGER
NUMBER   -> DECIMAL
BOOLEAN  -> BOOLEAN
```

There is **no** `RICH_OBJECT` mapping.

A provider that tries to expose `RICH_OBJECT` directly through the NoSQLServer
external relation fails at bind with:

```text
UNSUPPORTED_NOSQL_TYPE RICH_OBJECT
```

before provider execution.

The source-owning component must explicitly project a safe scalar relation if
SQL/MySQL visibility is required.

## Poisoned STRING regression

`test_rich_no_implicit_stringification.rex` uses a native object whose `STRING`
method raises an ooRexx syntax condition.

The complete path succeeds:

```text
native object
  -> RichEvidenceSourceRef
  -> RichEvidenceValue
  -> AlgorithmInputRelationSnapshot
  -> content hash
  -> RichBusinessFactAlgorithmProvider
  -> scalar evidence relations
```

proving that implicit native-object stringification is not required.

## Current platform baseline

Validated against:

```text
camera_behaviour_oorexx_v0.27
virtual_ryta_hardworld_v0.15
nosqlserver_v0.71
oorexx_db_skeleton_v0.36
algrel_cursor_probe_v0.1
msqlshim_v0.10
Open Object Rexx 5.3.0 r13196
```

The source-rich XML/EDIFACT/X12 implementation is an external plugin lane and is
not vendored into this package.  v0.15 defines the receiving contract on the
HardWorld / Algorithm Relation side.
