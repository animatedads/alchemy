# NoSQLServer v0.70 provider-neutral metadata boundary — v0.13

## Defect history

NoSQLServer v0.69 preserved external provider-specific metadata by delegating `tableMetadata()` to the external engine. That forced independently packaged providers to construct NoSQLServer-owned metadata objects, reintroducing package/global-class identity into an otherwise neutral relation contract.

Virtual RYTA v0.12 avoided the global-class lookup by making `TABLE_METADATA` a mandatory host-supplied class object.

NoSQLServer v0.70 fixes the deeper problem: federation owns metadata construction.

## v0.70 native contract

An Algorithm Relation external table supplies:

```text
definition
readRows / rowCount
```

and, only when semantically relevant, optional neutral relation capabilities such as geometry facts. NoSQLServer federation owns conversion to its own metadata classes.

The Algorithm Relation adapter therefore needs only the construction classes it directly instantiates:

```text
TABLE_DEFINITION
DATABASE_ROW
DATABASE_RESULT
```

NoSQLServer's metadata class is no longer a required dependency.

## Legacy compatibility

The adapter retains an optional `tableMetadata()` callback so a host that explicitly supplies `TABLE_METADATA` can still use the v0.69 callback path.

That method is not part of the v0.70 native integration contract. A v0.70 federated metadata lookup must leave `metadataFactoryCalls == 0`.

## Proven execution barrier

Stock v0.70 + Database Core v0.34 facade:

```text
source~tables              provider=0 metadata_factory=0
tableSource~metadata       provider=0 metadata_factory=0
tableSource~describe       provider=0 metadata_factory=0
first tableSource~rows     provider=1 metadata_factory=0
trace rows                 provider=1 metadata_factory=0
tableSource~query          provider=1 metadata_factory=0
```

Stock msqlshim v0.10 + stock v0.70:

```text
PREPARE actions            provider=0 metadata_factory=0
PREPARE trace              provider=0 metadata_factory=0
EXECUTE actions            provider=1 metadata_factory=0
FETCH                      provider=1 metadata_factory=0
EXECUTE trace              provider=1 metadata_factory=0
RESET + re-EXECUTE         provider=1 metadata_factory=0
```

## Architectural consequence

Metadata objects are host representation. Relation definitions are provider contract.

This keeps the boundary:

```text
Algorithm provider -> neutral typed relation
NoSQLServer         -> SQL/federation metadata representation
msqlshim            -> wire metadata representation
```

instead of making the provider instantiate objects belonging to every consumer above it.
