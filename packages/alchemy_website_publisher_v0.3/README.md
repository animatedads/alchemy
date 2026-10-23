# Alchemy Website Publisher v0.3 — native persistence integration

Separate Rasenfalcon-derived, side-by-side website editorial module. A full distribution ZIP is retained in the Alchemy project delivery, while this review increment publishes the independently owned **native storage integration** as source to GitHub.

## Selected backend

NoSQLServer **v0.90_sqlite_wal_read_write_candidate**, pinned SHA-256 `08534dc11858863a6efa82e4689e07ceb420691c4a9ab7fab7da69819c8cf9da`. It provides coherent WAL-aware read snapshots through `SQLiteWritableDatabaseEngine`. It remains a **development candidate**, not an accepted production database runtime. Native ooRexx execution has **not** been qualified for this Website Publisher on this branch.

The editor exports `alchemy.website.publisher.export/0.1` candidate JSON. ooRexx appends one immutable snapshot per native revision through NoSQLServer; no browser SQLite access, Python HTTP application, public publishing or approval authority.

## CLI

```sh
rexx native/publisher_store.rex init /private/publisher.sqlite
rexx native/publisher_store.rex save /private/publisher.sqlite candidate.json 0
rexx native/publisher_store.rex load /private/publisher.sqlite saved-r1.json 1
rexx native/publisher_store.rex history /private/publisher.sqlite history.tsv
rexx native/publisher_store.rex verify /private/publisher.sqlite
```

The `verify` operation checks revision-parent relationships; it is not a cryptographic verification or release approval. Site is explicitly fixed to `rasenfalcon.com`. Each revision is a single prepared INSERT, not a cross-statement transaction. A single authorised writer is required. Snapshot backup cost, crash-left temporary files, and predicate mutation races are documented by NoSQLServer v0.90.

## Qualification and GitHub scope

- Full v0.3 distribution: 46 browser checks + 36 native source/handoff checks passed.
- Native ooRexx smoke test included but **not run** (no qualified interpreter/native ABI here).
- This GitHub increment contains the native binding, CLI, native smoke test, pin and integration documentation. The full front-end asset/source import is **still behind** and should not be treated as synchronized by this branch.
- Remains `CANDIDATE_ONLY`; no Wire release, editorial approval, Connect Selector service binding, or HTTPS deployment.

The NoSQLServer upstream source is a dependency to be pinned, not copied as Publisher-owned source.
