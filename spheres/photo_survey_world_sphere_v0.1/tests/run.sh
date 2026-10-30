#!/bin/sh
set -eu
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
python3 - "$ROOT" <<'PY'
import hashlib,json,pathlib,sys
root=pathlib.Path(sys.argv[1]); pack=root/'packs'/'photo-survey-world'
sp=json.load(open(pack/'00-sphere.json'))
assert sp['id']=='photo-survey-world'
assert sp['version']=='0.1'
required={'ops.photo.start','arch.photo.authority-map','arch.photo.evidence-model','arch.photo.foreign-providers','arch.photo.indoor-room','ref.photo.current-baselines','ref.photo.source-compatibility-2026-10-29','ref.photo.qualification','ops.photo.next-work'}
assert required <= set(sp['start_here'])
arts={p.stem:json.load(open(p)) for p in (pack/'articles').glob('*.json')}
assert required <= set(arts)
assert all(a.get('authority')=='project-authoritative' for a in arts.values())
assert all(a.get('provenance') for a in arts.values())
start=arts['ops.photo.start']
assert start['current_baseline']['sha256']=='ab63a8fcd453623cc371ccfda71f60588256260251d6f71deb338a6e85b97707'
room=arts['arch.photo.indoor-room']
assert room['topology']==['LEFT_ALCOVE_REAR','LEFT_RETURN','CHIMNEY_BREAST_FACE','RIGHT_RETURN','RIGHT_ALCOVE_REAR']
assert room['measurements'][0]['metres']==2.750
assert room['measurements'][1]['metres']==3.750
assert room['measurements'][2]['metres']==5.000
base=arts['ref.photo.current-baselines']['baselines']
assert base['maths']['dev21_qualified']=='0.14'
assert base['maths']['current_canonical']=='0.19'
assert base['physics_world']['dev21_qualified']=='0.1-dev46'
assert base['physics_world']['current_canonical']=='0.1-dev50.2'
assert base['python_bridge']['dev21_qualified']=='Macrospace 0.31.6'
assert base['python_bridge']['historical_line_status']=='RETIRED_AS_PRODUCTION_DEVELOPMENT_LINE'
assert base['python_bridge']['current_adapter']=='alchemy_oorexxpython_upstream_adapter_v0.2'
assert base['oorexx']['dev21_qualification_runtime']=='5.3.0-r13196'
assert base['oorexx']['upstream_python_thread_gate']=='5.3.0-r13265+'
compat=arts['ref.photo.source-compatibility-2026-10-29']
assert compat['status']=='STATIC_SYMBOL_COMPATIBLE_NOT_RUNTIME_QUALIFIED'
assert compat['photo_world_files_checked']==11
assert 'MathMatrix~solve' in compat['maths_symbols_used']
manifest=root/'qualification'/'MANIFEST.sha256'
for line in manifest.read_text().splitlines():
    if not line.strip(): continue
    digest, rel=line.split(None,1); rel=rel.strip()
    assert rel!='qualification/MANIFEST.sha256'
    p=root/rel
    assert p.is_file(), rel
    assert hashlib.sha256(p.read_bytes()).hexdigest()==digest, rel
print('PASS photo-survey-world sphere continuity contract')
PY
