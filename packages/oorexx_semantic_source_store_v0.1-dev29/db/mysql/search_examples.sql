SELECT object_id, logical_name, object_kind, accepted_revision_id
FROM ssc_source_object
WHERE lookup_key = 'SEMANTICSOURCESTORE';

SELECT reference_id, from_object_id, from_revision_id, reference_kind, source_line
FROM ssc_semantic_reference
WHERE target_object_id = ?
ORDER BY from_object_id, source_line;

SELECT revision_id, object_id,
       MATCH(source_text) AGAINST (? IN BOOLEAN MODE) AS score
FROM ssc_source_revision
WHERE MATCH(source_text) AGAINST (? IN BOOLEAN MODE)
ORDER BY score DESC
LIMIT 100;

SELECT revision_id, object_id
FROM ssc_source_revision
WHERE source_text LIKE CONCAT('%', ?, '%')
LIMIT 100;
