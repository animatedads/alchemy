# MySQL / MariaDB backing profile

Semantic Source Control keeps one logical 47-table model. `db/mysql/schema.sql` is the MySQL-family physical projection of the same model used by `SemanticSourceStore~bootstrap` and by the PostgreSQL profile.

Use the existing Database Core / Native Database Backends MySQL/MariaDB executor and inject it through:

```text
.SemanticSourceStore~new(databaseRoot, sqlExecutor, "mysql")
```

SSC does not own database connectivity and does not introduce a private MySQL client.

## Physical differences from PostgreSQL

MySQL requires sized `VARCHAR` declarations, so identifiers are physically bounded (normally 191 characters for utf8mb4-safe indexed IDs), large source/document/evidence fields are `LONGTEXT`, hashes are `CHAR(64)`, and long paths are `VARCHAR(1024)` with prefix indexes where necessary. All tables use InnoDB and `utf8mb4_bin` so source spelling is not silently case-folded.

Apply `schema.sql`, bulk-copy/import, then `indexes.sql`. Run `ANALYZE TABLE` for the heavily populated tables after import. `ngram_optional.sql` is an optional MySQL-8-only profile when the ngram full-text parser is available and useful.

## Search strategy

The fast path remains semantic: object lookup, relations/references/runtime surfaces, then full-text source search. Built-in InnoDB FULLTEXT covers token-oriented searches. Arbitrary punctuation-heavy fragments are a weaker fit than PostgreSQL `pg_trgm`; use the optional MySQL 8 ngram parser or fall back to bounded literal search after semantic narrowing.
