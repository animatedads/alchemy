from pathlib import Path
import re

root = Path(__file__).resolve().parents[1]
store = (root / 'src' / 'SemanticSourceStore.cls').read_text()
schema = (root / 'db' / 'postgresql' / 'schema.sql').read_text()
indexes = (root / 'db' / 'postgresql' / 'indexes.sql').read_text()
trigram = (root / 'db' / 'postgresql' / 'trigram_optional.sql').read_text()

assert 'use strict arg databaseRoot, sqlExecutor, backendId' in store
assert 'sqlExecutor is required' in store
assert 'backendId must not be empty' in store
assert 'backendId = "nosqlserver"' not in store
assert 'self~sql = sqlExecutor' in store
assert 'storage_backend' in store
assert 'SCHEMA_VERSION "13"' in store

# The PostgreSQL schema must remain isomorphic with the portable bootstrap.
tables = re.findall(r'^CREATE TABLE\s+(ssc_[a-z0-9_]+)', schema, re.M)
assert len(tables) == 47, len(tables)
assert len(set(tables)) == len(tables)
for required in [
    'ssc_source_object', 'ssc_source_revision', 'ssc_relation',
    'ssc_semantic_reference', 'ssc_runtime_method_surface',
    'ssc_deployment', 'ssc_branch', 'ssc_auth_session'
]:
    assert required in tables, required

# Hot-path indexes for the 800k-line/source-graph workload.
for needle in [
    'ssc_source_object_lookup_idx',
    'ssc_source_revision_object_no_idx',
    'ssc_source_revision_fts_idx',
    "to_tsvector('simple'",
    'ssc_relation_from_kind_idx',
    'ssc_reference_target_kind_idx',
    'ssc_deployment_module_seq_idx',
    'ssc_runtime_method_lookup_idx',
    'ssc_auth_session_token_hash_uidx'
]:
    assert needle in indexes, needle

assert 'pg_trgm' in trigram
assert 'gin_trgm_ops' in trigram

# Persistence consumers must continue to go through store~sql rather than
# constructing their own NoSQLServer engines.
for p in (root / 'src').glob('*.cls'):
    if p.name == 'SemanticSourceStore.cls':
        continue
    text = p.read_text()
    assert 'FederatedDatabaseEngine~new' not in text, p.name
    assert 'NoSQLServerSQL~new' not in text, p.name

print('POSTGRESQL BACKING CONTRACT TEST: PASS')
