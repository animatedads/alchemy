#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
python3 - "$ROOT" <<'PY'
import json, pathlib, sys
root=pathlib.Path(sys.argv[1])
pack=root/'packs'/'access-permissions'
sphere=json.loads((pack/'00-sphere.json').read_text())
profile=json.loads((root/'profiles'/'access-permissions.json').read_text())
assert sphere['id']=='access-permissions'
assert sphere['version']=='0.3'
assert profile['id']=='access-permissions'
assert profile['version']=='0.3'
assert 'packs/core' in profile['packs'] and 'packs/access-permissions' in profile['packs']
articles={}
for p in (pack/'articles').glob('*.json'):
    o=json.loads(p.read_text())
    articles[o['id']]=o
for aid in sphere['start_here']:
    assert aid in articles, aid
required={
 'ap-three-layers','ap-authentication-attribution','ap-domain-admission',
 'ap-method-permissions','ap-enforcement-seam','ap-composition-flow',
 'ap-cryptographic-evidence','ap-policy-resolution','ap-session-policy-pinning',
 'ap-live-permission-policy','ap-session-close-revocation','ap-scope-exclusions',
 'ref.access-permissions.sources','qual.access-permissions.current'
}
assert required <= set(articles)
source_sha='e6421888aa40e302dcd1262cc4289ff6ab8df7c8c389595491d843973d52281e'
for aid in required:
    prov=articles[aid].get('provenance',[])
    assert prov, f'no provenance: {aid}'
    assert any(x.get('artifact')=='oorexx_access_permissions_v0.3.zip' and x.get('sha256')==source_sha for x in prov), aid
text=(articles['ap-three-layers']['summary']+' '+' '.join(articles['ap-three-layers']['invariants'])).lower()
assert 'grants no authority' in text
assert 'enter the building' in text
assert 'exact subject x object x method' in text
text=' '.join(articles['ap-enforcement-seam']['invariants']).lower()
assert 'security manager enforces' in text
text=' '.join(articles['ap-cryptographic-evidence']['invariants']).lower()
assert 'not a bearer capability' in text
print('PASS sphere structure, doctrine, provenance and start-here references')
PY
