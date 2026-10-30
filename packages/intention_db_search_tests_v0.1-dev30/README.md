# Intention Service × NoSQLServer search qualification v0.1-dev30

Direct source delta delivery because Autobuilder is offline.

Baseline: `packages/intention_db_search_tests_v0.1-dev29`.
Full source ZIP SHA-256: `7e5ad7f414b009fe814971c35e3846b8de4be55c4cbd49d9ed2519824e16e7bf`.

Dev30 changes:
- database capability evidence prefers public `db~version~supports(...)` for DISTINCT, GROUP_BY, LEFT_JOIN and AGGREGATES;
- SQL capability probes are compatibility fallback only;
- World `country.Population` is INTEGER again using the post-v0.84 exact integer contract;
- the World SQL importer accepts plain or backtick-quoted table names and rebuilds all 5,302 rows;
- runtime-evidence tests derive the active database release rather than hard-coding v0.84.

Qualification:
- real ooRexx 5.3.0 r13196 compatibility execution against the available v0.84 dependency: fixture, runtime evidence, evidence refresh, conversation transformations, backend composition and shell syntax PASS;
- source rebuild: country=239, city=4079, countrylanguage=984, total=5302 PASS;
- Git contract review of NoSQLServer v0.91: `NoSQLServer.cls` blob `223965361f10bd45d29d77a3db15faa38997241b`, validation blob `7f4207d7ecef2701fdf3f8f723323f2e7783a260`;
- Git now also contains NoSQLServer v0.92-dev1; dev30 does not claim local v0.91/v0.92 E2E execution.

`DEV30.patch` is the review delta. Qualification ledgers preserve the execution/contract boundaries.
