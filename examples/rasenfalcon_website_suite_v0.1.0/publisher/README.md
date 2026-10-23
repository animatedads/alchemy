# Alchemy Website Publisher v0.2 — native editorial snapshot integration

**Independent side-by-side website content editor** (Rasen Falcon reference implementation), now with a **real ooRexx NoSQLServer v0.89 storage adapter** and explicit revision handoff.

## Run the visual editor

Open `index.html` in Firefox or Chromium. No Python web server, PHP or SQLite binding is used by the web UI. Nine Rasen Falcon pages, structured forms, side-by-side live preview, original-vs-candidate compare, device previews, export, import, review-request preparation and static preview ZIP export are retained.

## Use NoSQLServer

1. Choose **Store in NoSQLServer** in the UI. It prepares a complete candidate export and shows the exact native CLI command for the expected native revision.
2. In a *qualified ooRexx runtime with NoSQLServer v0.89 dependencies installed*, run `rexx native/publisher_store.rex init` (once) and `save DATABASE FILE EXPECTED_REVISION` to append a single immutable editorial snapshot.
3. Run `rexx native/publisher_store.rex load DATABASE OUTPUT_FILE [REVISION]`, import that JSON file into the browser, and see the database revision in the UI. The next save uses that expected revision. `history DATABASE OUTPUT_FILE` exports a TSV revision ledger.

See `native/README.md` for environment and exact examples. The included `dependencies/nosqlserver_v0.89_sqlite_read_write_candidate.zip` is the exact dependency source inspected. Rebuild the native SQLite writer for the deployment ABI; don't silently use its bundled debug binary in production.

**Important status:** This is an explicit **file-to-native-CLI handoff**, not live browser-to-service persistence. ooRexx interpreter and C ABI were unavailable in this build environment; the native adapter is source-aligned with v0.89 but its runtime test must be executed on a qualified ooRexx host before claiming operational qualification. The browser tests and its original Rasen Falcon regression pass.

## Authority and constraints

This version does *not* publish, submit reviews, approve content, run a remote service, or grant access to privileged Wire/NoSQLServer objects. The browser has no database credentials or network write access. The NoSQLServer v0.89 writable SQLite engine is a **development candidate**, with per-statement atomicity but no cross-statement transactions, no WAL, and no multi-writer snapshot guarantees. A single local writer and strictly separate service permissions are required. Each stored revision is one INSERT; no prior revision is altered.

Production architecture remains: website editor (Wire presentation) → authenticated ooRexx CMS service → Connect Selector → native NoSQLServer → approved Wire resource/site release. Live authorisation and HTTPS deployment must be bound to real owner interfaces, not invented shortcuts.

## Tests

```sh
node --check publisher.js
python3 tests/test_publisher.py
python3 tests/test_native_handoff.py
```

The Python scripts above are **development-only browser and source tests**, never an application backend.

Qualified native runtime (separate):

```sh
rexx native/test_native_store.rex /private/new-test-editorial.sqlite
```

This native smoke was packaged but **not run** in the current environment.
