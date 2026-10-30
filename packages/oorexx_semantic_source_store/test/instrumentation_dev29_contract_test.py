from pathlib import Path
r=Path(__file__).resolve().parents[1]
p=(r/'src'/'SemanticSourcePackageService.cls').read_text()
o=(r/'src'/'SemanticSourceInstrumentationObserver.cls').read_text()
h=(r/'web'/'index.html').read_text()
assert 'QUERYSET_ASARRAY' in p and 'DATABASE_QUERY_COMPLETED' in p
assert 'PACKAGE_RESOURCES_MATERIALISED' in p and 'PACKAGE_MATERIALISED' in p
assert 'from_object_id IN (' in p and 'resource_revision_id IN (' in p
assert 'gaugeSeriesSet("semantic_source.database.query_seconds"' in o
assert 'instrumentation_freshness' in h
assert 'Freshness is observation evidence, not service health.' in h
print('SSC DEV29 INSTRUMENTATION CONTRACT: PASS')
