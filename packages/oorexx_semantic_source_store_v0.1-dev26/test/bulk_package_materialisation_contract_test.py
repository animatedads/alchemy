from pathlib import Path
p=Path(__file__).resolve().parents[1]/'src'/'SemanticSourcePackageService.cls'
s=p.read_text()
assert '::method queryRows private' in s
assert 'self~sql~hasMethod("QUERYSET")' in s
assert 'bulk~asArray' in s
assert '::method loadRevisionBatch private' in s
assert '::method validateRequiresBatch private' in s
assert 'JOIN ssc_source_revision r' in s
assert 'revision_id IN (' in s
# The sealed deployment path must not load each revision individually.
dep=s[s.index('::method getDeploymentPackage'):s.index('::method getBranchPackage')]
assert 'self~loadRevision(objectId, revisionId)' not in dep
assert 'objectRows = self~queryRows(objectSql)' in dep
# materialiseResolved must issue one projection query for the closure, not one per object.
mat=s[s.index('::method materialiseResolved private'):s.index('Build an immutable qualified deployment')]
assert 'revision_id IN (' in mat
assert mat.count('self~queryRows(') == 1
# The normal package resolver must not call per-object dependency/require validation helpers.
gp=s[s.index('::method getPackage'):s.index('::method resolveRevision private')]
assert 'self~dependenciesFor(' not in gp
assert 'self~validateRequiresExports(' not in gp
print('BULK PACKAGE MATERIALISATION CONTRACT TEST: PASS')
