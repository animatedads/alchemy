-- Optional MySQL 8 literal-fragment profile. Not claimed portable to MariaDB.
DROP INDEX ssc_source_revision_fts_idx ON ssc_source_revision;
CREATE FULLTEXT INDEX ssc_source_revision_fts_idx
  ON ssc_source_revision (source_text) WITH PARSER ngram;
