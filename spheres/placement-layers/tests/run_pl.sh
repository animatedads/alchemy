#!/bin/bash
set -euo pipefail
ROOT=$(cd "$(dirname "$0")/.." && pwd)
python3 - "$ROOT" <<'PY'
import hashlib,json,pathlib,sys
root=pathlib.Path(sys.argv[1])
for p in sorted(root.rglob('*.json')):
    json.loads(p.read_text())
manifest=json.loads((root/'00-manifest.json').read_text())
profile=json.loads((root/'profiles/placement-layers.json').read_text())
corpus=json.loads((root/'corpus/core.json').read_text())
assert manifest['id']=='placement-layers' and manifest['version']=='0.2'
assert profile['id']=='placement-layers' and profile['version']=='0.2'
ids=[x['id'] for x in corpus]
assert len(ids)==len(set(ids))
required={'pl-planned-admittance','pl-authoritative-revalidation','pl-observation-not-authority'}
assert required.issubset(ids)
articles={json.loads(p.read_text())['id'] for p in (root/'articles').glob('*.json') if p.name!='ref-sources.json'}
assert {'pl-admittance-flow','pl-planned-admittance-route','pl-managed-execution-boundary','pl-observation-boundary'}.issubset(articles)
readme=(root/'README.md').read_text()
for phrase in ['plan is evidence, not entitlement','WLU owns admission','Job-to-Node owns placement','Runtime observation is not release authority']:
    assert phrase.lower() in readme.lower(), phrase
print('PASS placement-layers v0.2 structural qualification')
PY
