# Semantic Source Store import cost vs store size (2026-10-24)

Architecture: Tom Dyer. Store coding: Claude (Opus 5.5) (dev26), ChatGPT (dev28). Probe and note: Claude (Opus 5.5).

## What was run

`slice.rex` imports the GA Intentions package (oorexx_ga_intentions_v0.1-dev1, 17 ooRexx files, 184 KB)
one file at a time, smallest first, through `SemanticSourceRepositoryService~importArchiveMember`
(store v0.1-dev28 source, NoSQLServer v0.79 file engine, Foreign Runtime v0.22.6 crypto, ooRexx 5.3.0
r13196, Anthropic cloud workspace). Budget 1,500 s. Log: `slice.log`; order: `files_smallest_first.txt`.

## Result

15 of 17 files, 388 semantic objects, 1,547 s. Least-squares fit over the 15 files:

    seconds per object = 2.23 + 0.0094 x (objects already in the store)

| Objects already stored | Observed s/object |
|---|---|
| 0 to 40 | 1.8 to 2.9 |
| 77 | 3.3 |
| 160 | 4.2 |
| 267 | 5.3 |

The growing term is the full-table scan behind every keyed SELECT (see `../nosqlserver_v091/`: 1.2 s per
primary-key lookup at 1,000 rows, unchanged in v0.91). The fixed term is mostly per-row INSERT cost
(about 70 ms per row on the file engine) times the rows written and read back per object.

## Consequence

Import time for N objects is roughly 2.23 N + 0.0047 N^2 seconds:

| N objects | Estimated time |
|---|---|
| 388 (observed) | 26 min |
| 625 (all of GA; measured 2026-10-24 on Rexx/SQL) | ~54 min for the import alone; the 2026-10-23 run that stopped at 2 h also accepts and rebuilds |
| 10,000 | ~5.7 days |

The store is functionally correct (round trip, method granularity and mutation tests pass) but cannot
import a real package set on NoSQLServer v0.79 or v0.91. Removing the N^2 term needs an indexed keyed
lookup in NoSQLServer; no change inside the store fixes it. Evidence category: LOCAL_PASS (measurement).

## Correction and follow-up (2026-10-24)

The table first estimated GA at ~1,100 objects from file sizes. Importing it completely (on Rexx/SQL)
counted 625, so the NoSQLServer import-only estimate is ~54 minutes, not ~2.3 hours.

The same import on SQLite through Mark Hessling's Rexx/SQL takes 3 s, flat ~4 ms per object, and
the full dogfood (import, accept, rebuild 17 files byte-identical) completes; see
`packages/oorexx_rexxsql_backend_v0.1/`.
