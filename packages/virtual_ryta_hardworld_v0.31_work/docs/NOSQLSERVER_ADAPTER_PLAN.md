# NoSQLServer Algorithm Relation integration plan — v0.16

## Current authoritative baseline

```text
NoSQLServer                 v0.71
Database Core skeleton      v0.36
msqlshim                    v0.10
Camera Behaviour            v0.27
Structured Relation Plugin  v0.5
Algorithm cursor probe      v0.1
Virtual RYTA / HardWorld    v0.16
```

No NoSQLServer or msqlshim patch is required for v0.16.

## Provider boundary

Algorithm Relation providers own:

- declared typed relation schema;
- canonical input/source identity;
- materialisation;
- typed internal values.

NoSQLServer owns SQL/federation metadata and query execution.  msqlshim owns
wire metadata/encoding.

## Scalar SQL types

The external adapter maps only:

```text
TEXT     -> VARCHAR
OID      -> VARCHAR
INTEGER  -> INTEGER
NUMBER   -> DECIMAL
BOOLEAN  -> BOOLEAN
```

`RICH_OBJECT` is intentionally absent.  A direct rich-object SQL relation is
rejected during bind before provider execution.

## Explicit rich projection

A source component that wants SQL exposure must explicitly project rich native
evidence into scalar relations. v0.16 includes `RichBusinessFactAlgorithmProvider`
as a reference evidence-only projection and `StructuredRelationRichEvidenceAdapter`
for the external structured_relation_plugin v0.5 RichBusinessFact contract.

No SQL projection may become an implicit authority promotion.

## v0.71 mutation boundary

Stock v0.71 resolves owning provider before mutation dispatch.  An UPDATE
against the read-only scalar rich-evidence external relation returns
`SQLUNSUPPORTED`, not FILE `NOTFOUND`, and does not re-execute the provider.

## Execution barrier

Current regressions prove:

```text
metadata / catalog / DB Core describe     0 executions
MySQL PREPARE                             0
first data demand                         1
rescan / second relation / JOIN           1
COM_STMT_FETCH                            1
RESET + re-execute                        1
```

The supplied `algrel_cursor_probe_v0.1` also passes unchanged when pointed at
the v0.16 tree, msqlshim v0.10 and NoSQLServer v0.71.

## Rich-object ownership

Rich source parsers remain external components. v0.16 does not parse XML,
EDIFACT or X12. The supplied structured_relation_plugin v0.5 now plugs into the
receiving boundary directly: its native source object, RichBusinessFact,
projection row, annotations, diagnostics and processing history remain reachable
while deterministic identity uses an explicit frozen evidence contract.

HardWorld may retain the evidence reference on a `RYTAFact`, but evidence does
not automatically change the fact's explicit value/epistemic state or produce
an authority disposition.
