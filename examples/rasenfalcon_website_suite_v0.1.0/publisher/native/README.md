# Website Publisher / native persistence handoff v0.2

## Status

NoSQLServer v0.89 **development candidate** is the selected storage interface. The ooRexx implementation calls `.SQLiteWritableDatabaseEngine~create/new`, `.NoSQLServerSQL~execute`, and `engine~insert`; browser code never connects to SQLite. The package has no Python application server. The ooRexx interpreter was **not available in the build environment**, so the native CLI is source-aligned but **not runtime qualified** in this release. Do not deploy as production or claim durability qualification until a real ooRexx v0.89 acceptance run succeeds.

## Native CLI

Extract a qualified NoSQLServer v0.89 package (SHA-256 pin recorded in docs/SOURCES.lock.json) in a dedicated directory. Rebuild the v0.89 native write bridge for your deployment's ooRexx runtime and C ABI. Install/use its dependencies Alchemy Objects and Crypto. Set `REXX_PATH` to contain the website publisher `native/` directory, the NoSQLServer `src/` directory, and the ooRexx/Alchemy dependencies. Set `LD_LIBRARY_PATH` to include the qualified v0.89 native library directory and ooRexx libraries.

```
rexx native/publisher_store.rex init     /private/rasen-publisher.sqlite
rexx native/publisher_store.rex save     /private/rasen-publisher.sqlite ./editorial-export.json 0
rexx native/publisher_store.rex load     /private/rasen-publisher.sqlite ./publisher-native-revision-1.json 1
rexx native/publisher_store.rex history  /private/rasen-publisher.sqlite ./publisher-history.tsv
```

`save` requires the current **native revision**, starting at `0`. `load` with omitted revision loads the latest. Paths supplied to this minimal CLI must not contain whitespace. `load` and `history` refuse to overwrite existing destination files.

In the browser choose **Prepare native save**. Its JSON candidate download is input to `save`. Then use `load` to obtain the versioned record and import it into the browser using **Import content**. This is an explicit file handoff, *not* automatic browser-to-database synchronization. The revision stored in the database is independent of the browser's draft-edit counter.

## Data model

`publisher_snapshots(revision INTEGER PRIMARY KEY, site TEXT, parent_revision INTEGER, recorded_at TEXT, document TEXT)` stores immutable JSON editorial exports, with one atomic prepared INSERT per revision. Every write verifies the expected site revision and never overwrites prior revisions. A unique primary key rejects races with conflicting global revision assignments. This is designed for **one approved local writer**; the v0.89 native reader does not provide a cross-transaction read snapshot for externally concurrent writers, so do **not** use this candidate as a multi-writer shared service. `recorded_at` is a local diagnostic clock observation, *not* Time Service authority.

The record body is opaque user-provided JSON. Importing it back into the browser checks the schema and page structure; the native store does **not** establish content truth, identity, authorisation, signatures, factual correctness, publication eligibility or institutional approval. No WAL; no cross-statement transactions. Storage Fabric and MI/MU portability are outside this local file ledger.

Security: choose a private database path on a confined writable volume, with no unrelated privileges; the browser never gets the path. The v0.89 exclusive-create file mode is 0600 on Linux; filesystem directory ACL and process identity remain deployment responsibilities.

No public HTTPS or Wire deployment path is provided. Keep the original Rasen Falcon content source and publish authority separate.
