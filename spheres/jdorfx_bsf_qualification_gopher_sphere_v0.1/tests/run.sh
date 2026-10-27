#!/usr/bin/env bash
set -euo pipefail
ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
python3 - "$ROOT" <<'PY'
import json,pathlib,sys
r=pathlib.Path(sys.argv[1]); p=r/'packs/jdorfx-bsf'
files=list(r.rglob('*.json'))
for f in files: json.loads(f.read_text())
sphere=json.loads((p/'00-sphere.json').read_text())
policy=json.loads((p/'01-access-policy.json').read_text())
profile=json.loads((r/'profiles/jdorfx-bsf.json').read_text())
assert sphere['access_policy']==policy['id'] and 'packs/jdorfx-bsf' in profile['packs']
arts={json.loads(f.read_text())['id']:json.loads(f.read_text()) for f in (p/'articles').glob('*.json')}
assert len(arts)==4
for a in arts.values():
    assert a['kind']=='article' and a['sphere']==sphere['id'] and a['provenance'] and a['invariants']
    assert all(x in arts for x in a['related'])
assert all(x in arts for x in sphere['start_here'])
q=json.loads((r/'qualification/STATUS.json').read_text())
assert q['production_admission']=='BLOCKED' and q['gopher_runtime']=='NOT_RUN'
print('PASS sphere static JSON and references; runtime NOT_RUN')
PY
