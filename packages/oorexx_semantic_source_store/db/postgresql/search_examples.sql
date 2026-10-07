-- Indexed examples used by CODE.SEARCH implementations on PostgreSQL.

-- Semantic name lookup: prefer this over searching source bodies.
SELECT object_id, language, object_kind, source_spelling, accepted_revision_id
FROM ssc_source_object
WHERE lookup_key = :lookup_key;

-- Full-text source search. Uses ssc_source_revision_fts_idx.
SELECT revision_id,
       object_id,
       changed_at,
       ts_rank(to_tsvector('simple', coalesce(source_text, '')),
               plainto_tsquery('simple', :query)) AS rank
FROM ssc_source_revision
WHERE to_tsvector('simple', coalesce(source_text, '')) @@ plainto_tsquery('simple', :query)
ORDER BY rank DESC
LIMIT :limit;

-- If trigram_optional.sql is installed, arbitrary literal substring searches
-- (including awkward programming-language fragments) use the trigram GIN index.
SELECT revision_id, object_id, changed_at
FROM ssc_source_revision
WHERE source_text ILIKE '%' || :literal || '%'
LIMIT :limit;
