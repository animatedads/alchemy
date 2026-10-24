# NoSQLServer v0.91: verification and defect re-probe (2026-10-24)

Architecture: Tom Dyer. NoSQLServer coding: ChatGPT. Probes and this note: Claude (Opus 5.5).
Host: Anthropic cloud workspace, ooRexx 5.3.0 r13196, system SQLite. Probes are in `../nosqlserver/`
(file engine) and `sqlprobe.rex` here (SQLite engine).

## Package's own test chain

`tools/run_sqlite_rw_v091.sh`, native library rebuilt from source on this host:
**LOCAL_PASS** (all v0.89, v0.74, v0.60, v0.90, v0.91 lines PASS/OK). Log: `run_sqlite_rw_v091.log`.

Defect: only `run_sqlite_rw_v091.sh` was executable; it calls `run_sqlite_rw_v090.sh` directly,
so the documented command failed with "Permission denied". Fixed by setting the mode on all
`tools/*.sh` (no content change).

## v0.79 defects re-probed on v0.91

| Defect (v0.79) | v0.91 file engine | v0.91 SQLite engine |
|---|---|---|
| UPDATE evaluates quoted literals (`'3*4'`->12, `'12-34'`->-22, `'NULL'`->nil); `'a-b'` refused | **FIXED** | FIXED |
| CRLF rewritten to LF | still present | **preserved** |
| `IN (...)` lists | not implemented | not implemented |
| `CREATE INDEX` | unsupported | n/a |
| Primary-key lookup is a full scan | still `TABLE_SCAN`: 0.24 s at 250 rows, 1.20 s at 1,000 rows (same as v0.79) | `SQLITE_NATIVE_SCAN`: 0.10 s at 250 rows, 0.53 s at 1,250 rows |
| Insert cost | 70 ms/row, flat | grows: 59 ms/row at 250 -> 297 ms/row at ~1,000 |

Logs: `defect_probes_v0.79.log`, `defect_probes_v0.91.log`, `sqlprobe.log`.

## Consequence for Semantic Source Control

v0.91 removes the need for the UPDATE workaround but does not make the store usable at package
scale: every keyed lookup still reads the whole table. The missing NoSQLServer feature is an
indexed primary-key (and secondary-key) lookup path. The SSC compatibility shim (`IN` rewrite)
is still required.
