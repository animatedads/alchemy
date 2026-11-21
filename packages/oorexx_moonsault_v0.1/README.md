# Moonsault — Yale BSC5 J2000 seed catalogue

Date: 2026-11-02. User architecture: Moonsault/SLAM and the Alchemy-owned database execution stack.

## Data provenance

- Upstream source: [brettonw/YaleBrightStarCatalog](https://github.com/brettonw/YaleBrightStarCatalog), `bsc5-short.json` on `master`, Git blob SHA `78768ccb6b7fe308e8ddfed8003a5bc60a4c3cc4`.
- Original base catalogue: Yale Bright Star Catalogue, fifth edition. Upstream conversion project is MIT licensed; retain its LICENSE attribution.
- Export: `data/yale_bsc5_j2000.csv`, 9,096 records (9,110 nominal HR IDs with gaps). Each `hr` is unique. All entries have parseable RA, Dec and visual magnitude.
- `ra_deg_j2000`: right ascension expressed as decimal degrees in [0,360); `dec_deg_j2000`: signed declination in [-90,90]. Both are the catalogued J2000 coordinates, **not** positions propagated to November 2026.
- `color_temperature_k`: source's **approximate**, inferred colour temperature, not a measured thermometer value. Null where unavailable.
- Empty `common_name`, `bayer`, `flamsteed` and `constellation` fields mean unspecified; they are not invented.

**Limitation:** This short JSON edition has no proper motions, parallaxes or uncertainty covariance. Use it for initial star recognition and catalog ID matching, *not* for an unqualified high-precision geodetic fix. Planetary positions and the Moon require separate dated ephemerides.

## Native NoSQLServer import

Use the repository's `packages/nosqlserver_v0.92-dev1` writable SQLite provider. It retains Alchemy's SQL parser and query authority; SQLite is the local storage backend. This is not a Python runtime or external SQLite SQL engine.

Build the NoSQLServer native writer for the target platform as described by `SQLITE_READ_WRITE_v0.89.md`; set ooRexx and package paths in `REXX_PATH` and the target writer shared library path in `LD_LIBRARY_PATH`. Do not transplant a development machine binary onto deployment hosts.

```
rexx tools/moonsault_import_bsc5.rex \
  data/yale_bsc5_j2000.csv /path/to/approved/moonsault.sqlite
```

Before writing, the script rejects bad schema, duplicate HR, nonnumeric/out-of-range astrometry, missing rows and missing HR1/HR9110. It then creates a `moonsault_bsc5` table **only if it is absent**. Each 50-row INSERT is a NoSQLServer-managed atomic statement. The script checks readback of all 9,096 rows. The importer deliberately does **not** overwrite an existing table or claim a cross-batch transaction.

For a parser-only preflight with no database mutation:

```
rexx tools/moonsault_import_bsc5.rex data/yale_bsc5_j2000.csv unused.sqlite VALIDATE_ONLY
```

## Database storage and authority

The target path must be selected by the Alchemy deployment owner; no remote deployment target is assumed here. The SQLite backend is a local file, **not** the distributed Storage Fabric or MU-wide database authority. Movement into shared persistent services requires an explicit integration/migration step and appropriate owner approval. The data is staged as a table with a distinct name, so it cannot overwrite another catalogue.

## Qualification

- Parsed upstream JSON into 9,096 source objects; no invalid J2000 RA/Dec, missing visual magnitudes or duplicate HR identifiers.
- Native ooRexx 5.3.0 r13196 executed preflight against a generated 9,096-row schema-valid fixture; PASS. This test exercises pre-validation only, **not live NoSQLServer insertion**.
- Reference star-source and CSV source must be checked again against the stored version before operational acceptance. Do not assert a successful live import until an actual NoSQLServer insert and readback have passed.
## SLAM450 Unix clock adapter (v0.93 candidate)

The existing `.MoonsaultEphemeris~sunMoon(utc,lat,lon)` accepts strict ISO-8601 UTC text and also integer Unix/POSIX UTC seconds in 1970-2099 for the SLAM450 flight clock. Predictions retain their provenance and `PREDICTION_ONLY` status. A seven-epoch regression was added as `tests/test_unix_slam450.rex`; run it with the existing `test_ephemeris.rex` before merging. The standalone Rexx conversion primitive passed 5/5 boundary cases on user-supplied 5.3.0 r13196; provider integration testing is pending.

This branch does not alter the separate 9,096-row Yale BSC5 CSV or the importer. The writable NoSQLServer import still requires a live insert/readback test on an explicitly chosen target database; passing source preflight is not a stored-database claim.
