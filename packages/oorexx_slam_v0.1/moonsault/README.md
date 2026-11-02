# Moonsault BSC5 / own database intake (2026-11-02)

**Architecture:** Tom Dyer. **Additive catalogue import:** ChatGPT (GPT-6).
**Scope:** data intake only; no changes to deployed SQL services and no unapproved production cutover.

## Source and provenance

- Yale Bright Star Catalogue fifth preliminary edition (BSC5), secondary pre-parsed
  repository: https://github.com/brettonw/YaleBrightStarCatalog
- Input: `bsc5-short.json`, Git blob
  `78768ccb6b7fe308e8ddfed8003a5bc60a4c3cc4`.
- Input contains **9096** rows (HR 1–9110, with 14 historical catalogue entries omitted).
  All 9096 input rows passed unique HR, coordinate parsing and numeric magnitude checks.
- Converted coordinates: source J2000 equinox/epoch, RA converted from hours to
  degrees, declination from signed sexagesimal to degrees.
- Extra columns: V magnitude, proper name, Bayer, constellation abbreviation,
  Flamsteed and **approximate** temperature. Empty optional values remain empty
  in CSV, or SQL NULL for Flamsteed/temperature.
- Source licence/attribution: consult the source repository's MIT LICENSE and
  underlying Yale catalog attribution. Retain this provenance with derived rows.

## Files

| File | Purpose |
|---|---|
| `bsc5_j2000.csv` | Verified 9096-row CSV for Alchemy; HR unique ID |
| `bsc5_j2000_seed.sql` | Schema and 9096 INSERTs, SQLite single transaction |
| `import_bsc5.rex` | ooRexx-native NoSQLServer SQLiteWritable importer, refuses existing DB |
| `README.md` | Source, import and qualification instructions |

## Fast, isolated one-time bootstrap

```sh
# Use a NEW catalogue path, not an existing service database:
test ! -e moonsault_bsc5.sqlite || exit 1
sqlite3 moonsault_bsc5.sqlite < bsc5_j2000_seed.sql
sqlite3 moonsault_bsc5.sqlite 'PRAGMA integrity_check; SELECT COUNT(*) FROM moonsault_bsc5;'
# Expected: ok then 9096
sqlite3 moonsault_bsc5.sqlite 'SELECT hr,proper_name,ra_j2000_deg,dec_j2000_deg FROM moonsault_bsc5 WHERE hr IN (424,2491,7001);'
```

This bootstrap writes a standard SQLite database file readable/writable by
Alchemy's `NoSQLServerSQLiteWritable.cls`. SQLite is the *physical* store;
NoSQLServer remains the application database interface. It avoids the full
NoSQLServer snapshot-per-statement cost for 9096 initial inserts.

## ooRexx-native alternative

From this directory, with the matching NoSQLServer sources and native binary
dependencies available:

```sh
rexx import_bsc5.rex bsc5_j2000.csv /var/lib/alchemy/moonsault_bsc5.sqlite
```

The Rexx importer uses `SQLiteWritableDatabaseEngine` and
`NoSQLServerSQL` directly. It refuses to overwrite an existing file and tests
presence of HR 424 (Polaris), 2491 (Sirius), 7001 (Vega).

This initial import is **not** yet claimed as a successful live deployment:
repository access does not provide the destination database, host permission,
or runtime configuration. No SQL was executed against a user's existing live
Alchemy database. A database owner should select its destination and run
one of the import options, then report the row-count and integrity result.

## Astronomical qualification limits

J2000 coordinates are catalogue reference coordinates. This BSC5 **short**
source has no proper-motion vectors, parallaxes, observer-dependent alt/az,
horizon calibration, UT1 correction, or planetary/lunar ephemerides. Do not
interpret the catalogue as an already qualified 2026 celestial navigation fix.
Photo star-matching and geodetic position solving require independent tests.
Gemini-authored names/magnitudes are **not** used for the trusted data set.
