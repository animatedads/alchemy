# SSC high-volume backing comparison

Both candidates use the same logical 47-table Semantic Source Control schema and the same injected Database Core executor contract.

| Concern | PostgreSQL profile | MySQL / MariaDB profile |
|---|---|---|
| Semantic/B-tree lookup | indexed | indexed |
| Relation/reference traversal | indexed | indexed |
| Runtime class/method surface | indexed | indexed |
| Source token search | GIN `to_tsvector('simple', ...)` | InnoDB FULLTEXT |
| Arbitrary code substring | optional `pg_trgm` GIN | ordinary FULLTEXT is weaker; optional MySQL-8 ngram parser |
| Punctuation-heavy fragments | strong with `pg_trgm` | benchmark required |
| Source case fidelity | preserved in semantic model | `utf8mb4_bin` physical collation |
| Connectivity owner | Database Core / Native Database Backends | Database Core / Native Database Backends |
| SSC-specific DB client | none | none |

## Benchmark before cutover

Load the same production snapshot and record cold/warm timings for:

1. exact class/method `lookup_key` lookup;
2. accepted/current revision lookup;
3. find-uses by `target_object_id`;
4. callers/callees relation traversal;
5. runtime class inspection surface;
6. module/deployment resolution;
7. bearer-session lookup;
8. token source search (`SemanticSourceStore`, `::requires`, common method names);
9. punctuation/literal fragments (`foo~bar`, `.Class`, `::METHOD`, partial identifiers);
10. incremental `since` class-inspection refresh.

Correctness gate: row counts, IDs, source hashes, accepted revision IDs, sealed deployment manifests, provenance, and authorization results must match before changing the authoritative backend.
