-- Optional PostgreSQL acceleration for arbitrary substring/punctuation-oriented
-- source searches. Requires permission to install pg_trgm.
CREATE EXTENSION IF NOT EXISTS pg_trgm;

CREATE INDEX ssc_source_revision_source_trgm_idx
  ON ssc_source_revision USING GIN (source_text gin_trgm_ops);
CREATE INDEX ssc_source_object_source_spelling_trgm_idx
  ON ssc_source_object USING GIN (source_spelling gin_trgm_ops);
CREATE INDEX ssc_source_object_logical_name_trgm_idx
  ON ssc_source_object USING GIN (logical_name gin_trgm_ops);

ANALYZE ssc_source_revision;
ANALYZE ssc_source_object;
