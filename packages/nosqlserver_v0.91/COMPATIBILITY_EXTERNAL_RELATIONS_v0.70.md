# NoSQLServer v0.70 external relation compatibility

## Boundary repaired

The v0.69 federated metadata path delegated `tableMetadata(tableName)` to an
external engine when that method existed.  This preserved GeoPackage geometry
facts but unintentionally required an independently packaged external adapter
to resolve and instantiate NoSQLServer's `DatabaseTableMetadata` class.

Virtual RYTA / HardWorld v0.11 exposed this immediately.  Against untouched
v0.68 its external-engine regression passes; against v0.69 it failed during
metadata lookup with an ooRexx object-method-not-found error on
`.DATABASETABLEMETADATA`, before algorithm execution.

v0.70 does not solve this by exporting more global classes or by teaching the
adapter about v0.70.  Federation owns metadata construction again.

For any relation object:

1. `definition` supplies the neutral relation/column schema.
2. If the relation exposes `geometryColumn`, `geometryType`, or `srid`, those
   capabilities enrich the geometry metadata.
3. Provider identity is not inspected.
4. Provider `tableMetadata()` is not required for federated discovery.

This lets old external adapters remain old while newer relations may expose
richer facts directly.

## Verified companion packages supplied with this continuation

### Virtual RYTA / HardWorld v0.11

The stock v0.11 lazy Algorithm Relation external-engine test passes against
v0.70.  Catalog and metadata lookup do not invoke Virtual RYTA.  First SQL read
materializes once; rescans/joins reuse that materialization.

The v0.11 Librarian external-engine test also passes.  Librarian relations stay
evidence relations; NoSQLServer performs no promotion into HardWorld facts or
RYTA authority.

### Camera Behaviour ooRexx v0.26

Camera v0.26's native `CameraMaterializedStateSnapshot` was exercised directly
as generic NoSQLServer frozen object relations.  Frozen condition, completed
regime, and regime-class objects were mapped by ordinary getter names and
queried/joined by SQL.  Later mutation of the live Camera state did not affect
either Camera's canonical materialization or the NoSQLServer snapshot.

No Camera class name or Camera-specific branch was added to NoSQLServer.

The HardWorld v0.11 Camera Algorithm Relation adapter still describes a v0.20
surface and was also run unchanged as a backwards-compatibility probe against
the v0.26 Camera class.  That does not claim that the old adapter captures the
new v0.26 complete materialized-state contract.

### msqlshim v0.10

msqlshim was rebound to the v0.70 `NoSQLServer.cls` without source changes.
Text protocol, compressed protocol, utility commands, multi-client isolation,
binary prepared statements, read-only prepared cursors, `COM_STMT_FETCH`, mixed
compressed/uncompressed backpressure, and FIFO backend fairness passed.

This remains a wire-layer compatibility consumer.  No MySQL-specific semantics
were added to NoSQLServer for this work.
