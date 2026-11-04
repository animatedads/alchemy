from pathlib import Path
import re

root = Path(__file__).resolve().parents[1]
store = (root / 'src' / 'SemanticSourceStore.cls').read_text()
schema = (root / 'db' / 'mysql' / 'schema.sql').read_text()
indexes = (root / 'db' / 'mysql' / 'indexes.sql').read_text()
ngram = (root / 'db' / 'mysql' / 'ngram_optional.sql').read_text()
pg_schema = (root / 'db' / 'postgresql' / 'schema.sql').read_text()

assert 'use strict arg databaseRoot, sqlExecutor, backendId' in store
assert 'self~sql = sqlExecutor' in store
assert 'backendId must not be empty' in store
assert 'storage_backend' in store

mysql_tables = re.findall(r'^CREATE TABLE\s+(ssc_[a-z0-9_]+)', schema, re.M)
pg_tables = re.findall(r'^CREATE TABLE\s+(ssc_[a-z0-9_]+)', pg_schema, re.M)
assert len(mysql_tables) == 47, len(mysql_tables)
assert mysql_tables == pg_tables, (len(mysql_tables), len(pg_tables))
assert len(set(mysql_tables)) == 47

# Physical MySQL-family requirements.
assert 'ENGINE=InnoDB' in schema
assert 'DEFAULT CHARSET=utf8mb4' in schema
assert 'COLLATE=utf8mb4_bin' in schema
assert 'LONGTEXT' in schema
assert 'CHAR(64)' in schema
assert not re.search(r'\bVARCHAR\b(?!\s*\()', schema), 'unsized VARCHAR remains'

for needle in [
    'ssc_source_object_lookup_idx',
    'ssc_source_revision_object_no_idx',
    'CREATE FULLTEXT INDEX ssc_source_revision_fts_idx',
    'ssc_relation_from_kind_idx',
    'ssc_reference_target_kind_idx',
    'ssc_deployment_module_seq_idx',
    'ssc_runtime_method_lookup_idx',
    'ssc_auth_session_token_hash_uidx',
]:
    assert needle in indexes, needle

assert 'origin_member_path(191)' in indexes
assert 'relative_path(191)' in indexes
assert 'projection_path(191)' in indexes
assert 'WITH PARSER ngram' in ngram
assert 'Not claimed portable to MariaDB' in ngram

# Persistence consumers remain backend-neutral.
for p in (root / 'src').glob('*.cls'):
    if p.name == 'SemanticSourceStore.cls':
        continue
    text = p.read_text()
    assert 'FederatedDatabaseEngine~new' not in text, p.name
    assert 'NoSQLServerSQL~new' not in text, p.name

print('MYSQL BACKING CONTRACT TEST: PASS')
