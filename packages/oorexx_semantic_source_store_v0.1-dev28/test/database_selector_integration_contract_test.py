from pathlib import Path
root = Path(__file__).resolve().parents[1]
src = root / "src"
violations=[]
for p in src.glob("*.cls"):
    t=p.read_text()
    for forbidden in (
        '::requires "NoSQLServer.cls"',
        '.FederatedDatabaseEngine',
        '.NoSQLServerSQL',
        'PostgreSQLNativeBackend',
        '.MySQL',
    ):
        if forbidden in t:
            violations.append((p.name, forbidden))
if violations:
    raise SystemExit(f"backend leakage into neutral SSC source: {violations}")
store=(src/'SemanticSourceStore.cls').read_text()
assert 'sqlExecutor is required' in store
assert 'DatabaseBackendSelector' in store
comp=(src/'SemanticSourceDatabaseComposition.cls').read_text()
assert 'provider package' in comp
assert 'newStore' in comp
compose=(src/'compose_semantic_source_store.rex').read_text()
for forbidden in (
    '::requires "NoSQLServer.cls"',
    '::requires "database_core.cls"',
    'PostgreSQLNativeBackend',
    '.FederatedDatabaseEngine',
    '.NoSQLServerSQL',
):
    assert forbidden not in compose, f"backend leakage into composition root: {forbidden}"
assert 'DatabaseBackendSelector.cls' in compose
assert 'OOREXX_DATABASE_PROVIDER' in (src/'setup_semantic_source_db.rex').read_text()
print('DATABASE SELECTOR INTEGRATION CONTRACT TEST: PASS')
