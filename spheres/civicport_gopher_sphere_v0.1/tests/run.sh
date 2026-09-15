#!/usr/bin/env bash
set -euo pipefail
ROOT=$(cd "$(dirname "$0")/.." && pwd)
python3 - "$ROOT" <<'PY'
import json, pathlib, sys
r=pathlib.Path(sys.argv[1])
s=json.loads((r/'packs/civicport/00-sphere.json').read_text())
assert s['id']=='civicport'
assert s['version']=='0.1'
assert 'ops.civicport.start' in s['start_here']
p=json.loads((r/'profiles/civicport.json').read_text())
assert p['packs']==['packs/core','packs/oorexx','packs/civicport']
arts=list((r/'packs/civicport/articles').glob('*.json'))
assert len(arts)>=12
for f in arts:
    a=json.loads(f.read_text())
    assert a['sphere']=='civicport'
    assert a.get('authority')
    assert a.get('provenance'), f'{f.name} missing provenance'
c=json.loads((r/'packs/civicport/corpora/civicport.continuity.json').read_text())
by={x['key']:x for x in c['records']}
assert by['release-head']['value']=='civicport_v0.14.zip'
assert by['mapping-notam-runway']['value']=='faa.swim.aim-fns.notam-runway-closure/0.1'
assert 'NOT_FOR_OPERATIONAL_USE' in by['notam-use']['value']
print('PASS civicport sphere semantic checks')
PY
