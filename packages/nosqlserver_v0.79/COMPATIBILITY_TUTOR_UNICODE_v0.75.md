# Optional TUTOR Unicode compatibility — NoSQLServer v0.75

## Boundary

Unicode support is optional. `src/NoSQLServer.cls` does not contain a
`::REQUIRES` for TUTOR and the normal CLASSIC path has no TUTOR dependency.

Enable explicitly:

```rexx
.NoSQLUnicodeSupport~enable("/path/to/TUTOR")
```

The root may contain `bin/Unicode.cls`; a direct directory containing
`Unicode.cls` is also accepted.

A `textMode: UNICODE` VARCHAR/TEXT column fails closed if TUTOR has not been
enabled. CLASSIC is the default at both table and column level.

## Tested provider

User-supplied TUTOR 0.7 corpus, under ooRexx 5.3.0 r13196.

TUTOR describes itself as a prototype whose interfaces may change. Therefore
NoSQLServer deliberately keeps the adapter narrow and optional.

TUTOR is Apache License 2.0. No TUTOR source or Unicode Character Database files
are redistributed inside NoSQLServer v0.75.

## Semantics

UNICODE values are represented internally as TUTOR `Text` objects.

That supplies:

- strict UTF-8 validation;
- NFC normalization;
- Extended Grapheme Cluster indexing;
- Unicode upper/lower mappings;
- canonical-equivalent equality after NFC normalization.

At the delimited FILE storage boundary, Unicode objects are serialized as their
normalized UTF-8 byte string. They are recreated as TUTOR Text when rows are
read through a UNICODE column definition.

Consequences:

- composed `Café` and decomposed `Cafe\u0301` compare equal in UNICODE mode;
- a UNICODE PRIMARY KEY treats those spellings as the same key;
- the same two byte strings remain distinct under CLASSIC mode;
- `CHAR_LENGTH('Café')` is 4 in UNICODE mode;
- `OCTET_LENGTH('Café')` is 5;
- `SUBSTR` and LIKE `_` operate on grapheme clusters for TUTOR Text values.

## Deliberate non-claims

v0.75 does not claim:

- locale/language collation;
- Unicode tailoring;
- ICU collation;
- automatic conversion of legacy encodings;
- implicit Unicode enablement;
- automatic schema migration from CLASSIC to UNICODE.

Ordering of UNICODE values is deterministic normalized UTF-8/code-point order.

## Provider neutrality

`textMode` belongs to `DatabaseColumn` / `TableDefinition`, not to FILE or JSON.
The JSON explicit projection boundary can opt a projected VARCHAR/TEXT column
into UNICODE by passing `textMode="UNICODE"` to `JsonColumnProjection`.

No JSON-specific, GeoPackage-specific, JOIN-specific or msqlshim-specific
Unicode planner branch is required.
