# Integration v0.2 — bounded native storage

This is an additive extension to the v0.1 standalone Website Publisher. The UI and Rasen Falcon nine-page content semantics remain unchanged.

**Selected database**: NoSQLServer v0.89's `SQLiteWritableDatabaseEngine`, not a direct Python `sqlite3` connection. The application class `CmsWebsiteSnapshotStore` creates/opens the selected backend, creates a single `publisher_snapshots` table through `.NoSQLServerSQL`, and appends candidate exports through `engine~insert` with a `.table` of typed values. User-provided JSON never becomes SQL source. Every revision is one SQLite prepared INSERT via NoSQLServer's native writer.

**Concurrency and atomicity**: A persisted revision number is an increasing integer primary key, with a `parent_revision` and explicit expected previous site revision. The engine's unique PK rejects colliding inserts. Because v0.89 has no cross-statement transaction, the adapter refuses multi-record editorial commits and is approved only as a single local writer candidate. Concurrency with other writers must be disallowed at deployment until an owning lease/transaction boundary is available. A stale request returns an error without modifying previous revisions.

**UI exchange**: Browser **Store in NoSQLServer** exports `alchemy.website.publisher.export/0.1`. CLI `save` stores its raw bytes as an opaque candidate document. CLI `load` returns `alchemy.website.publisher.native-record/0.2` with numeric native revision, backend, candidate-only authority and original JSON payload. Browser validates the record, site, content structure and intended status. Browser download alone does not change native storage. These files are untrusted input; the database adapter does not verify content claims.

**Source and authority**: Native persistence is not a publication decision, an authenticated review, an independent evidence check or approval. The Rasen Falcon original deterministic compiler, Wire resource editor, Institutional Policy and owned HTTPS server remain the release authorities. Neither public browsing nor the browser editor can directly reach the database.

**Pending**: qualified native runtime/ABI and tests; ooRexx CMS read/write service; Connect Selector binding; authenticated multi-user review; Time Service authority for timestamps; end-to-end Wire/UI and RexxOS security qualification. These must be integrated by their owners before production.
