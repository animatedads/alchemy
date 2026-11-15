# ooDialog Database Lab v0.1 — Alchemy NoSQLServer test component

Architecture: Tom Dyer. Code: ChatGPT (GPT-6).

This is an ooRexx **model** for a user-facing database test bench in the
ooDialog Designer and ooRexx Object Editor. The HTML/JavaScript editor only
projects its results and sends intentions. All database creation, table
definitions, SQL execution, validation and data access go through **Alchemy
NoSQLServer**.

The browser creates a *separate* ooRexx/WASM session for the lab. It does not
load `NoSQLServer.cls` into the editor's reflection/compilation session: that
would collide with any classes that the user's code happens to load.
Refusals use this package's own language resources in English and German,
through the shared OodNls mixin. The page selects the designer's language
when opened and displays the refusal, without the ooRexx 93.900 wrapper.

## Backend selection and limitations

- This v0.1 lab uses `FileDatabaseEngine` (Alchemy NoSQLServer v0.92-dev1):
  YAML catalog and typed delimited table storage under an isolated root.
- No native SQLite backend is silently selected. `SQLiteWritableDatabaseEngine`
  needs the native `nosqlsqlitewriter` library, unavailable in the browser's
  WASM runtime. It remains an independent, explicit native-only option.
- SQL has NoSQLServer semantics: `CREATE TABLE`, `DROP TABLE`, `SELECT`,
  `INSERT`, `UPDATE`, `DELETE`, and supported queries. `ALTER TABLE` is **not**
  supported by the underlying SQL executor. In this lab, `replaceEmptyTable`
  validates a replacement definition, refuses all populated tables, refuses
  declared foreign-key relations and uses DROP/CREATE only for an empty table.
  A create failure attempts to restore its old empty definition; this is not
  a transactional migration API. Never use it to remodel valuable data.
- Table/drop operations are confined to the chosen root; user-supplied database,
  table and column identifiers are restricted to ASCII alphanumeric/underscore
  names starting with a letter or underscore (max 64 characters).
- `executeJSON` projects the first 200 result rows. The underlying query runs
  with its own NoSQLServer access path. Use `LIMIT` on exploratory large queries.
- No multi-user claims, production credentials, MI/MU, network database or
  secure transaction certification are implied. Browser data lives only for
  that runtime session and is discarded when the editor reloads.

## Model API

```rexx
::requires "OodDatabaseLab.cls"
lab = .OodDatabaseLab~new("/tmp/disposable-db-lab")
lab~createDatabase("test_contacts")
lab~createTable("people", "id" || "09"x || "INTEGER" || "09"x || "0" || "09"x || "1" || "09"x || "0")
say lab~executeJSON("INSERT INTO people (id) VALUES (1)")
say lab~previewJSON("people")
```

| Method | Purpose |
| --- | --- |
| `language(lang)` | Choose refusal strings from the lab's own resources (English or German). |
| `databaseNames`, `createDatabase(name)`, `openDatabase(name)` | Create/select a named database within the lab root. |
| `tableNames`, `schema(name)` | Inspect Alchemy's catalog and typed columns. |
| `createTable(name, tabSeparatedColumns)` | Validate a table definition, then issue NoSQLServer DDL. |
| `replaceEmptyTable(name, tabSeparatedColumns)` | Redefine only a genuinely empty, unreferenced table. |
| `dropTable(name)` | Explicitly drop a selected test table. |
| `executeJSON(statement)`, `previewJSON(name)` | Execute one SQL statement and project diagnostics and up to 200 rows as JSON. |

`tabSeparatedColumns` contains one row per column, with five tab-separated
fields: `name`, `type`, `nullable` (`0`/`1`), `primary` (`0`/`1`), `unique`
(`0`/`1`). The editor's table grid presents these fields; validation belongs
to the ooRexx model.

## Qualification

The smoke test creates an isolated directory supplied by the caller. It covers
database creation and reopening, catalogue listing, table definition,
insert/update/delete/query, an empty-table schema change, and refusal of
unsafe names, duplicate databases, unknown types and populated-table changes.

For the Node edition of ooRexx/WASM 0.2.4 (`npm i oorexxwasm@0.2.4`), from
this package's directory:

```sh
temp_root=$(mktemp -d /tmp/ood-dblab.XXXXXX)
export REXX_PATH="$PWD/src:/path/to/alchemy/packages/nosqlserver_v0.92-dev1/src:/path/to/alchemy/packages/alchemy_objects_v0.8/src:/path/to/alchemy/packages/oorexx_crypto_v0.1/src:/path/to/alchemy/packages/oorexx_oodialog_designer_v0.8/src"
rexx tests/database_lab_smoke.rex "$temp_root"
```

The test only creates new data beneath its exact temporary root. Do not pass
a directory holding existing data.
The Autobuild schema 0.3 manifest invokes tests/autobuild_gate.sh, which
creates and removes its own private test root.

The consuming editor source/build lives on `animatedads/oorexx`, branch
`oodialog-designer`, under `oodialog-designer/site/database-lab.*` and
`oodialog-designer/tools/database.rex`. This package is canonical; the build
copies exact source files rather than inventing a second database implementation.
