# Rexx/SQL 2.6B3: patches for ooRexx 5, GCC 14 and the SQLite3 driver

For Mark Hessling, from the Alchemy project (Tom Dyer). Patches written and tested by Claude (Opus 5.5), 2026-10-24.

## Source

`rxsql26B3/` is Rexx/SQL 2.6B3 (23 May 2011) exactly as distributed:
`rxsql26B3_src.zip`, SHA-256 `57e5b7082ce141820c0fd6c8a26e0c82da8b625f090ff454497d62fd1f8e59e8`.
Rexx/SQL is © Mark Hessling, distributed under the GNU Library General Public License (`rxsql26B3/COPYING-LIB`).
The patches below are offered under the same licence. They are applied at build time by
`../tools/build_rexxsql.sh`; the vendored tree itself is unmodified.

Test platform: Ubuntu 24.04 x86-64, GCC 13.3 (also built with GCC 14's default-error checks:
`-Werror=implicit-int -Werror=incompatible-pointer-types -Werror=implicit-function-declaration
-Werror=int-conversion`), ooRexx 5.3.0 r13196 64-bit, SQLite 3.45.1.

## Patches

| # | File(s) | Problem | Fix |
|---|---|---|---|
| 0001 | `configure`, `common/accommon.m4`, `aclocal.m4` | ooRexx 5 ships no `oorexx-config`, and the check accepted only major version 4, so ooRexx 5 fell into the pre-4.0 Object REXX branch and failed to compile (`ULONG`, `PSZ`, `PUCHAR` unknown). Debian/Ubuntu keep libraries in `/usr/lib/<multiarch>`, which was not searched. The fallback library search tested `mh_db_inc_dir` instead of `mh_db_lib_dir`, so it never ran. | `OOREXX_40` for major >= 4, and without `oorexx-config` when `rexx.h` declares `RexxReturnCode`. Multiarch dir from `cc -print-multiarch`. Guard corrected. |
| 0002 | `common/rxmt*.c`, `common/rxmt.h`, `general/rxsqlinc2.h` | Errors under GCC 14: `IfcRxPackCleanup( VOID )` (VOID undefined, so an implicit-int parameter); `MTMalloc` declared with `long size`, implemented with `size_t`; `RexxSQLInitHandler` hard-coded `LONG` where `RexxExitHandler` is `int`. | `void`; `size_t` throughout; `REH_RETURN`/`REH_ARG*_TYPE` from `rxdef.h`. |
| 0003 | `sqlite3/sqlite3.c`, `general/rxsqlinc2.h` | (a) `FetchRow`/`SetRowCountVar` built `stem.column.n` with `sprintf` into a `MAX_IDENTIFIER`-sized stack buffer; SQLite column names are unbounded (an unaliased expression is named by its text), so `select 'a' || 'a' || ...` aborted the interpreter (`*** buffer overflow detected ***`). (b) Text measured with `strlen()`: values truncated at the first NUL byte. (c) BLOB columns always returned `""`. (d) `sprintf(tmp, ...)` of 255-byte identifiers into `tmp[128]`. | Heap buffer when the name does not fit (an invalid Rexx name now returns rc -16); `sqlite3_column_bytes()`; `sqlite3_column_blob()`; `snprintf(tmp, sizeof(tmp), ...)`. |
| 0004 | `sqlite3/sqlite3.c` | `SelectStatement()` recognises only a leading `SELECT`. Through `SQLCOMMAND`, `WITH ... SELECT`, `PRAGMA`, `EXPLAIN`, `VALUES` and `... RETURNING` failed with "another row available" or returned no rows. Through `SQLEXECUTE`, a `PRAGMA` or `INSERT ... RETURNING` reported "another row available" after the statement had already run. | After `sqlite3_prepare`, `sqlite3_column_count() > 0` marks the statement as a query for fetching. The original classification is kept (`leading_select`) for everything else: `SQLEXECUTE` steps a non-SELECT statement to completion and discards its rows; a SELECT through `SQLEXECUTE` and the AUTOCOMMIT rule are unchanged. |

With all four, `./configure --with-rexx=oorexx --with-db=sqlite3 && make` works with no extra options
on Ubuntu 24.04, and `samples/tester.cmd` produces the same output as the unpatched build.

## Evidence

- `samples/tester.cmd` (setup + all exercises): passes before and after; output identical.
- `../tests/test_rexxsql_driver.rex`: 52 checks. The unpatched build fails at the NUL-byte round trip;
  the BLOB and long-column-name defects were reproduced separately on the unpatched build
  (`../evidence/`).
- 120,000 keyed SELECTs through `SQLCOMMAND`: resident memory flat at 28 MB; about 80 us per call
  at 20,000 rows.

## Not changed (noted for you)

- `sqlite3_prepare(..., -1, ...)`: SQL text stops at a NUL byte. Values containing NUL go through
  placemarkers (which already pass the length).
- `NULLSTRINGIN` defaults to `""`, so an empty bound string is stored as SQL NULL. Documented
  behaviour; left alone.
- Rexx/SQL binds every value as text; there is no BLOB bind type.
