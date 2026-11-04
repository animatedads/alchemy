# Moonsault: native NoSQLServer Yale Bright Star CSV ingestion

**Status (2026-11-02):** 9,096-row source CSV committed in `packages/moonsault/data/yale_bright_stars_j2000.csv`. Source data verified for valid numeric J2000 coordinates and unique HD/HIP identifiers. Preflight and import written for ooRexx 5.3.0 r13196. Preflight passed a seven-row source excerpt and rejected a deliberate duplicate. The actual NoSQLServer import has **not** been executed against the user's deployed database.

## Provenance

- Source: https://github.com/isene/starmap
- Source snapshot commit: `504bcd08ae90f2ca5772dca99de716db3c29e09f`
- CSV Git blob SHA-1: `c7b9458deeb6aaa2d8fc71e98c47ea8cfcca4f6c` (Git object hash; not SHA-256).
- Layout: `ra,dec,mag,bv,spectral,hd,hip,dist_pc,name`. Right ascension and declination are J2000 degrees.
- 9,096 records, 101 missing HIP, 310 missing B−V, 1,727 missing distance, 8,763 no proper name. HD identifier is present and unique in all records; this derivative lacks HR numbers.
- Source data: Yale Bright Star Catalogue 5th Revised, supplemented with Hipparcos distances and IAU proper star names. Source repo uses the Unlicense/public-domain claim; preserve its attribution.

## Preflight

From `packages/moonsault/bsc5`:

```shell
rexx bsc5_preflight.rex ../data/yale_bright_stars_j2000.csv
```

Fails if the expected 9,096 rows, 9 columns, numeric RA/Dec and uniqueness of HD/HIP are violated.

## Import into Alchemy's own NoSQLServer

The operator supplies the existing **FILE-engine** database root explicitly; no database host, path or backend is guessed. NoSQLServer v0.92-dev1 and its dependencies `csvStream.cls`, `yaml.cls`, `json.cls` and `AlchemyObject.cls` must be available on the ooRexx package path. Do not load `database_core.cls` alongside NoSQLServer's namespaced adapter (class collision).

```shell
rexx import_bsc5_nosql.rex ../data/yale_bright_stars_j2000.csv /path/to/existing/nosqlserver-root
```

The loader fully validates input **before opening the database**, then refuses existing table names. It stages `moonsault_bsc5`, `moonsault_catalogue_sources`, and all prepared inserts in one NoSQLServer transaction; a failed step rolls back rather than publishing partial rows. It checks COMMITTED and verifies the final row count.

**Qualification limitation:** The importer has passed syntax qualification, not an end-to-end remote database load. Test against a database clone before deployed operation. It does not touch the existing SLAM `SlamStore` SQLite store.

**Astrometric limit:** J2000 coordinates with no proper-motion vectors or uncertainty are suitable for basic star-pattern identification, not for accurate 2026 navigation. Precision positioning must incorporate date-corrected positions, Earth rotation, refraction, camera calibration and an observable local horizontal/vertical.
