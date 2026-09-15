#!/bin/sh
set -eu
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
RUNTIME_ZIP=${VMM_RUNTIME_ZIP:-}
UI_ZIP=${VMM_UI_ZIP:-}
python3 - "$ROOT" "$RUNTIME_ZIP" "$UI_ZIP" <<'PY'
import hashlib, json, pathlib, sys, zipfile
root=pathlib.Path(sys.argv[1]); rz=sys.argv[2]; uz=sys.argv[3]
pack=root/'packs'/'vector-meridian-markets'
sp=json.load(open(pack/'00-sphere.json'))
assert sp['id']=='vector-meridian-markets'
assert sp['version']=='0.1'
assert 'ops.vmm.start' in sp['start_here']
arts={p.stem:json.load(open(p)) for p in (pack/'articles').glob('*.json')}
required={'ops.vmm.start','arch.vmm.legal-perimeter','arch.vmm.execution-authority','arch.vmm.smart-routing','arch.vmm.institutional-synthetics','arch.vmm.default-closeout','arch.vmm.netting-custody','arch.vmm.accounting','arch.vmm.security-seams','arch.vmm.ui-authority','arch.vmm.ui-row-list-contract','ops.vmm.rebase-versioning','ref.vmm.protocols','ref.vmm.source-map','ref.vmm.qualification'}
assert required <= set(arts)
assert arts['ref.vmm.protocols']['protocols']['federation_arm_length']=='vmm.federation.arm_length/0.3'
assert arts['ref.vmm.protocols']['protocols']['wire_ui_release']=='VECTOR_MERIDIAN_MARKETS_OPERATIONS@3'
assert arts['arch.vmm.ui-row-list-contract']['implementation_status'].startswith('Required baseline')
assert any('semanticRowId' in x for x in arts['arch.vmm.ui-row-list-contract']['invariants'])
assert arts['ops.vmm.start']['current_baselines']['runtime_sha256']=='4ebde9b8ca4ca158906bd42d4367bb3040b83b598b8bd41850addfe6518e3509'
assert arts['ops.vmm.start']['current_baselines']['ui_sha256']=='b988c0f4677bb094e92c9aa8245425cc3c5f0687eda66083a5a5df2d7de481b9'
cor=json.load(open(pack/'corpora'/'vmm.lessons.json'))
assert len(cor['records']) >= 12

def check_artifact(path, expected):
    if not path: return None
    p=pathlib.Path(path); got=hashlib.sha256(p.read_bytes()).hexdigest(); assert got==expected,(p,got,expected)
    return zipfile.ZipFile(p)
r=check_artifact(rz,'4ebde9b8ca4ca158906bd42d4367bb3040b83b598b8bd41850addfe6518e3509')
u=check_artifact(uz,'b988c0f4677bb094e92c9aa8245425cc3c5f0687eda66083a5a5df2d7de481b9')
for a in arts.values():
    for ev in a.get('provenance',[]):
        if ev['artifact']=='vector_meridian_markets_v0.11.zip' and r is not None:
            assert ev['member'] in r.namelist(), ev['member']
        if ev['artifact']=='vector_meridian_markets_wire_ui_web_v0.3.zip' and u is not None:
            assert ev['member'] in u.namelist(), ev['member']
print('PASS vector-meridian-markets sphere structure/provenance contract')
PY
