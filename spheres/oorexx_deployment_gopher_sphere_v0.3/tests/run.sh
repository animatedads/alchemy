#!/bin/sh
set -eu
ROOT=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
python3 - "$ROOT" <<'PY'
import json, sys
from pathlib import Path
root=Path(sys.argv[1])
pack=root/'packs'/'oorexx-deployment'
manifest=json.loads((pack/'00-sphere.json').read_text())
assert manifest['id']=='oorexx-deployment'
assert manifest['version']=='0.3'
articles={p.stem:json.loads(p.read_text()) for p in (pack/'articles').glob('*.json')}
assert len(articles)==26, len(articles)
for sid in manifest['start_here']:
    assert sid in articles, sid
for aid,a in articles.items():
    assert a['kind']=='article' and a['sphere']=='oorexx-deployment'
    assert a.get('provenance'), aid
corpus=json.loads((pack/'corpora'/'oorexx-deployment.continuity.json').read_text())
assert corpus['kind']=='corpus' and corpus['sphere']=='oorexx-deployment'
assert len(corpus['records'])==56, len(corpus['records'])
rules={r['id']:r['rule'] for r in corpus['records']}
for rid in ('single-flight','hosted-lifecycle','native-loadability','dependencies-before-mutation','ssc-authority'):
    assert rid in rules, rid
assert 'sealed-ssc-production' in rules and 'exact transitive' in rules['sealed-ssc-production']
assert 'development-vs-sealed' in rules and 'must reproduce' in rules['development-vs-sealed']
assert 'namespace-after-semantics' in rules and 'deterministic target namespace' in rules['namespace-after-semantics']
assert 'component-root-substitution' in rules and 'substituted provider' in rules['component-root-substitution']
assert 'rexx-path-replacement' in rules and 'replaces ambient REXX_PATH' in rules['rexx-path-replacement']
q=articles['oorexx-deployment.qualification']
assert q['baseline']['current_candidate']['sha256']=='c6f04ddc6bcb80963161d3312b773cbc4c58fdbd2f99907662aa4a0d6ad23ce2'
assert q['baseline']['last_full_runtime_qualified']['sha256']=='796b4375b7abac6e13e5f23f632c8aa75f86fe777f3d7c130ea8e440ff5dbd79'
assert 'pending' in q['baseline']['current_candidate']['runtime_status']
assert 'oorexx-deployment.ssc-sealed-deployments' in articles
assert 'oorexx-deployment.dependency-namespace' in articles
kg=articles['oorexx-deployment.known-gaps']
assert 'Open' in kg['status']
cc=articles['oorexx-deployment.concurrency']
assert 'not claimed as implemented' in cc['implementation_status']
print('PASS sphere structure: 26 articles, 56 continuity records')
print('PASS start_here/article/provenance integrity')
print('PASS candidate-vs-last-runtime-qualified baseline separation')
print('PASS sealed SSC release authority doctrine')
print('PASS deterministic dependency namespace doctrine')
PY
