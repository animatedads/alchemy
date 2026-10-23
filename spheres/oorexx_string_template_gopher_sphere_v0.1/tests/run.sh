#!/bin/sh
set -eu
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
python3 - "$ROOT" <<'PY'
import hashlib,json,pathlib,sys
root=pathlib.Path(sys.argv[1])
pack=root/'packs'/'oorexx-string-template'
sp=json.load(open(pack/'00-sphere.json'))
profile=json.load(open(root/'profiles'/'oorexx-string-template.json'))
policy=json.load(open(pack/'01-access-policy.json'))
assert sp['id']=='oorexx-string-template'
assert sp['version']=='0.1'
assert profile['id']==sp['id'] and profile['version']==sp['version']
assert 'packs/oorexx-string-template' in profile['packs']
assert policy['id']=='oorexx-string-template-access'
arts={p.stem:json.load(open(p)) for p in (pack/'articles').glob('*.json')}
assert set(sp['start_here']) <= set(arts)
for a in arts.values():
    assert a['sphere']==sp['id']
    assert a['authority']=='project-authoritative'
    assert a.get('provenance')
    for rel in a.get('related',[]): assert rel in arts, (a['id'],rel)
start=arts['ops.template.start']
assert start['current_baseline']['version']=='0.1-dev2'
assert start['current_baseline']['carrier_sha256']=='ec8cf86c920cf34a989bd03336a7e08ec0cd0e034675010438c3dab0063d34fc'
qual=arts['qual.template.current']['evidence']
assert qual['dev1_runtime'].startswith('PASS')
assert qual['dev2_standards']=='PASS 0 errors 0 warnings'
assert qual['dev2_runtime']=='NOT_RERUN'
manifest=root/'qualification'/'MANIFEST.sha256'
for line in manifest.read_text().splitlines():
    if not line.strip(): continue
    digest,rel=line.split(None,1); rel=rel.strip()
    assert rel!='qualification/MANIFEST.sha256'
    target=root/rel
    assert target.is_file(),rel
    assert hashlib.sha256(target.read_bytes()).hexdigest()==digest,rel
print('PASS oorexx-string-template sphere structure/continuity contract')
PY
