# PostgreSQL backing for Semantic Source Control

Semantic Source Control schema v13 separates the semantic store from its physical SQL executor.

`SemanticSourceStore~new(databaseRoot, sqlExecutor, backendId)` now accepts any executor implementing the shared database result contract used by NoSQLServer/Database Core. If `sqlExecutor` is omitted, the historical `FederatedDatabaseEngine + NoSQLServerSQL` backing remains the compatibility default.

For the production/high-volume path, construct the accepted Database Core PostgreSQL/libpq executor and inject it with `backendId="postgresql"`. This package deliberately does **not** invent a second PostgreSQL client implementation: Database Core / Native Database Backends owns PostgreSQL connectivity.

## Installation order

1. Create the PostgreSQL database/user through normal infrastructure management.
2. Apply `schema.sql`.
3. Apply `indexes.sql`.
4. Optionally apply `trigram_optional.sql` if `pg_trgm` is available.
5. Start the SSC authority with its Database Core PostgreSQL executor injected into `SemanticSourceStore`.
6. Bulk-import semantic content through the normal MCP import authority.

`schema.sql` is generated from the same 47 portable table definitions used by the NoSQLServer bootstrap. There is therefore no parallel semantic schema to maintain.

## Why PostgreSQL for the large source corpus

The Examiner should resolve semantic identity first and search source bodies second. PostgreSQL indexes make both paths cheap:

- B-tree indexes cover lookup keys, object/revision history, graph edges, module/deployment closure, runtime class surfaces, branches and authentication sessions.
- A built-in GIN `to_tsvector('simple', source_text)` index provides fast code-text search without English stemming.
- Optional `pg_trgm` GIN indexing accelerates arbitrary literal/substring searches where programming punctuation makes full-text tokenisation unsuitable.

For a corpus on the order of 800,000 source lines, this means `CODE.SEARCH` should query indexed semantic objects/revisions rather than walk materialised files.

## Migration rule

Do not copy private backing files or mutate PostgreSQL directly behind MCP. Migrate through authoritative export/import or a one-shot administrative migration that preserves every semantic ID, revision ID, archive hash, member path, status and provenance field. After migration, compare row counts and content hashes before changing the live backing.
