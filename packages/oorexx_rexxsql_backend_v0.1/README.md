# ooRexx Rexx/SQL backend v0.1 (SQLite)

**Architecture:** Tom Dyer (NativeDatabaseBackend contract; backend-neutral Semantic Source Store).
**Rexx/SQL:** Mark Hessling (LGPL), version 2.6B3, plus five patches.
**Patches, backend and tests:** Claude (Opus 5.5), 2026-10-24.

Mark Hessling's Rexx/SQL gives ooRexx a function-call SQL interface to SQLite (and MySQL, ODBC,
Oracle, DB2). This package brings it into Alchemy as a `NativeDatabaseBackend`, family `SQLITE`,
implementation `rexxsql`, and proves it under the Semantic Source Store's own tests.

Why: NoSQLServer (v0.79 and v0.91) looks up rows by key with a full table scan, so the store's
import cost grows with the square of its size (see
`review/claude-independent-engineering-2026-10-23/ssc_scale/`). SQLite through Rexx/SQL has
real primary and secondary indexes.

## Results (LOCAL_PASS, Anthropic cloud workspace, ooRexx 5.3.0 r13196, SQLite 3.45.1)

| | NoSQLServer v0.79 | Rexx/SQL + SQLite |
|---|---|---|
| Keyed lookup | 1.2 s at 1,000 rows (full scan) | ~80 us at 20,000 rows (index) |
| Store round-trip suite | 87.4 s, 30 checks | 0.4 s, 28 checks (CRLF path: see below) |
| GA Intentions import (17 files, 625 objects) | 15 files in 1,547 s; cost/object grows | all 17 in 3 s; flat ~4 ms/object |
| GA dogfood: import, accept, rebuild 17 files byte-identical | stopped at 2 h, unfinished | 17.5 s for all four suites |
| NoSQLServer v0.91 source as the corpus (117 files, 2,295 revisions) | not attempted | 49 s with the index plan, 43 s without; 117/117 byte-identical |
| CRLF | rewritten to LF; store refuses the import | stored exactly |

The round-trip suite has 28 checks on SQLite against 30 on NoSQLServer because CRLF is stored and
read back instead of being refused (a different branch of the same test).

## Contents

| Path | What |
|---|---|
| `upstream/rxsql26B3/` | Rexx/SQL 2.6B3 source exactly as distributed (SHA-256 of the zip in `upstream/UPSTREAM.md`) |
| `upstream/patches/` | Five patches, ready to send to Mark (`UPSTREAM.md` explains each) |
| `tools/build_rexxsql.sh` | Applies the patches to a copy and builds `librexxsql.so` |
| `src/RexxSqlBackend.cls` | `RexxSqlSqliteBackend`, `RexxSqlSqliteSession`, `RexxSqlResult`, `RexxSqlRow` |
| `src/RexxSqlPlanAudit.cls` | Session that records every statement whose query plan scans a whole table |
| `adapters/ssc/SemanticSourceSqliteIndexPlan.cls` | The store's secondary indexes, applied as the store creates its tables |
| `adapters/ssc/SemanticSourceRexxSqlProvider.cls` | Provider half of the store's composition seam: provider id `rexxsql-sqlite` → a bootstrapped store |
| `adapters/ssc/compose_ssc.rex` | Composition-root script: resolves `OOREXX_DATABASE_PROVIDER` and builds the store |
| `adapters/ssc/run_ssc_live_on_rexxsql.sh` | Runs the store's own live tests on Rexx/SQL, changing only the executor line |
| `tests/` | Driver (52), backend-contract (24) and provider-selection (11) tests |
| `evidence/` | Before/after logs for every defect, Mark's suite, memory, query-plan audits |

## Use

```
sh tools/build_rexxsql.sh /some/dir
```
```
export LD_LIBRARY_PATH=/some/dir
```

```rexx
-- Semantic Source Store, selected by provider id through the store's composition seam.
-- The store stays backend-neutral; this provider package supplies the executor.
store = .SemanticSourceRexxSqlProvider~newStore("/data")   -- bootstrapped, backendId "rexxsql-sqlite"
-- or build the store's composition boundary yourself:
comp = .SemanticSourceRexxSqlProvider~composition("/data")
store = comp~newStore ; store~bootstrap
-- or, generally, just an executor:
session = .RexxSqlSqliteSession~open("/data/app.sqlite")
r = session~execute("SELECT object_id FROM t WHERE kind='METHOD'")   -- r~status, r~message, r~rows, r~rowCount
r = session~executeBound("INSERT INTO t (k,v) VALUES (?,?)", .array~of(.array~of("CHAR","k1"), .array~of("TEXT", text)))
::requires "SemanticSourceRexxSqlProvider.cls"   -- pulls the index plan, composition and session
```

From a composition root, select by environment instead of in code:

```
OOREXX_DATABASE_PROVIDER=rexxsql-sqlite  rexx adapters/ssc/compose_ssc.rex /data
```

`execute` never raises for SQL errors: the result has `status` "ERROR" and the message.
Sessions open in WAL mode with `synchronous=NORMAL` (options `journal_mode`, `synchronous`).

## Published limitations

- Results are materialised as Rexx variables by `SQLCOMMAND`; narrow very large SELECTs.
- Result column names are upper case; `RexxSqlRow` lookups are case-insensitive.
- A result column must be a valid Rexx tail: alias expressions (`SELECT count(*) AS n`).
- SQL text stops at a NUL byte; send such values with `executeBound`.
- An empty bound string is stored as SQL NULL (Rexx/SQL `NULLSTRINGIN`); it reads back as "".
- No BLOB bind type (BLOB columns are readable).
- One process-wide current connection in Rexx/SQL; sessions switch with `SQLDEFAULT` automatically.
  Not tested across threads.

## Tests

```
sh run_tests.sh
```

Builds from source, then runs the driver test, the backend-contract test and the store's live
suites (round trip, MCP operations, semantic mutation) on Rexx/SQL. Needs gcc, make, patch,
SQLite 3 and ooRexx headers.

## Query-plan audit of the store

`evidence/ssc_scan_audit_without_plan.log`: one GA dogfood run scanned `ssc_resource_relation`
7,634 times, `ssc_relation` 66, `ssc_source_unit` 50. With the index plan
(`ssc_scan_audit_with_plan.log`) only deliberate full reads remain, plus 17 scans of
`ssc_source_unit.projection_path`; that index was added to the plan after this log was taken.
Measured cost and benefit of the index plan: it removes every avoidable scan, but at the sizes
tested it does not pay for itself. GA dogfood: import 8.3 s with the plan, 4.2 s without. NoSQLServer
v0.91 source (2,295 revisions): 49 s with, 43 s without. SQLite scans a few thousand rows in
microseconds. The plan stays the default because the estate is roughly 35 times larger than the
largest corpus tested and a scan's cost grows with both table size and call count; that benefit is
an engineering expectation, not yet measured. `SSC_INDEX_PLAN=0` switches it off for comparison.
