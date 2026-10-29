#!/bin/bash
set -euo pipefail
ROOT=$(cd "$(dirname "$0")/.." && pwd)
python3 - "$ROOT" <<'PY'
import json,pathlib,sys
root=pathlib.Path(sys.argv[1])
for p in sorted(root.rglob('*.json')): json.loads(p.read_text())
m=json.loads((root/'00-manifest.json').read_text())
p=json.loads((root/'profiles/placement-layers.json').read_text())
c=json.loads((root/'corpus/core.json').read_text())
assert m['id']=='placement-layers' and m['version']=='0.4'
assert p['id']=='placement-layers' and p['version']=='0.4'
ids=[x['id'] for x in c]
assert len(ids)==len(set(ids))
required={'pl-planned-admittance','pl-authoritative-revalidation','pl-observation-not-authority','pl-llm-route-selection','pl-operational-correlation','pl-rto2-compute-projection'}
assert required.issubset(ids)
arts={json.loads(x.read_text())['id'] for x in (root/'articles').glob('*.json') if x.name!='ref-sources.json'}
assert {'pl-llm-model-routing','pl-operational-correlation','pl-rto2-compute-projection','pl-observation-boundary'}.issubset(arts)
r=(root/'README.md').read_text().lower()
for phrase in ['plan is evidence, not entitlement','wlu owns admission','job-to-node owns placement','ai model router','rto2','correlation']: assert phrase in r
print('PASS placement-layers v0.4 structural qualification')
PY
