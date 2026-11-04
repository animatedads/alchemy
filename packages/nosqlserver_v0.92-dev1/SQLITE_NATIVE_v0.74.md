# NoSQLServer v0.74 native SQLite storage

## Architectural boundary

SQLite is treated as a binary storage format, not as an authority that must be
reached through a foreign SQL runtime.

```text
SQLite / GeoPackage file
        |
        v
SQLiteNativeDatabase
  header / pages / b-tree / records / overflow
        |
        +--------------------+
        |                    |
        v                    v
SQLiteDatabaseEngine   GeoPackageDatabaseEngine
ordinary relations     gpkg catalog + typed geometry
        |                    |
        +---------+----------+
                  v
            NoSQLServer SQL
                  |
          federation / DB Core
```

The native layer does not parse application SELECT statements. It returns
faithful storage values; NoSQLServer remains the relational execution layer.

## Native objects

### SQLiteNativeDatabase

Owns the file-format reader. It validates the `SQLite format 3` header, page
size, reserved-byte count and text encoding. Pages are read on demand with
absolute `CHARIN` positions.

`schema` reads the `sqlite_schema` table rooted at page 1 and returns
`SQLiteNativeTable` objects. `rows(tableName)` walks that table's b-tree and
returns ooRexx table objects keyed by the declared column names.

### SQLiteNativeTable / SQLiteNativeColumn

Carry the CREATE TABLE-derived storage metadata needed to map record fields to
columns. `INTEGER PRIMARY KEY` rowid aliases are identified explicitly.
Table-level primary-key declarations are retained. `WITHOUT ROWID` is detected.

### SQLiteNativeBlob

Holds the original BLOB byte string. `hex` is an explicit rendering; the
binary object remains available to higher layers before projection.

### SQLiteDatabaseEngine

Read-only ordinary SQLite relation provider. It maps SQLite declared types onto
NoSQLServer's existing INTEGER / DECIMAL / DATE / DATETIME / BLOB / TEXT
surface and executes NoSQLServer SQL over decoded rows.

### GeoPackageDatabaseEngine

Uses the same native reader for `gpkg_contents`, `gpkg_geometry_columns` and
feature/attribute tables. The declared geometry BLOB is promoted to
`GeoPackageGeometry` with geometry type and SRID; other BLOBs remain ordinary
`SQLiteNativeBlob` values.

## Implemented SQLite file-format pieces

- 100-byte database header
- 512..65536-byte database pages
- reserved-byte-aware usable page size
- table b-tree interior page type `0x05`
- table b-tree leaf page type `0x0d`
- cell pointer arrays and right-most interior child
- 1..9 byte SQLite varints
- signed 64-bit rowids
- table-leaf local-payload calculation
- overflow page linked lists
- SQLite record headers and serial-type varints
- serial types 0..9
- variable BLOB / TEXT serial types >= 12
- IEEE-754 binary64 REAL decoding
- UTF-8 TEXT
- `sqlite_schema` CREATE TABLE parsing sufficient for ordinary SQLite and
  GeoPackage schemas, including quoted identifiers and table-level PK metadata

## Deliberate boundaries

v0.74 is read-only. It does not claim:

- SQLite mutation or transaction-file writing
- WAL or rollback-journal replay
- index b-tree query execution
- `WITHOUT ROWID` payload decoding
- virtual table implementations
- UTF-16le / UTF-16be TEXT decoding
- SQLite SQL, trigger or VM execution
- spatial predicate evaluation

NoSQLServer can still filter, join, aggregate and federate rows after decoding.
The boundary is storage fidelity first, relational projection second.
