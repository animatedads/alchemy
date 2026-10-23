#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
python3 - "$ROOT" <<'PY'
import json, pathlib, sys
root=pathlib.Path(sys.argv[1])
pack=root/'packs'/'virtual-usb'
sphere=json.loads((pack/'00-sphere.json').read_text())
profile=json.loads((root/'profiles'/'virtual-usb.json').read_text())
assert sphere['id']=='virtual-usb' and sphere['version']=='0.1'
assert profile['id']=='virtual-usb' and profile['version']=='0.1'
assert 'packs/core' in profile['packs'] and 'packs/virtual-usb' in profile['packs']
articles={}
for p in (pack/'articles').glob('*.json'):
    o=json.loads(p.read_text())
    assert o['sphere']=='virtual-usb'
    articles[o['id']]=o
required={
'vusb.current','vusb.layering','vusb.raw-gadget','vusb.fido-development-boundary',
'vusb.dependency-authority','vusb.whole-device-trust','qual.virtual-usb.current',
'ops.virtual-usb.continuation','ref.virtual-usb.sources'}
assert required <= set(articles), required-set(articles)
assert set(sphere['start_here']) <= set(articles)
PKG_SHA='efa8a1e5a31a8ae7e39360b5f9495772ef1132dccb620d1a896320d24edbc8f6'
for aid in required:
    prov=articles[aid].get('provenance',[])
    assert prov, f'no provenance: {aid}'
    assert any(e.get('sha256')==PKG_SHA for e in prov), aid
raw=' '.join(articles['vusb.raw-gadget']['invariants']).lower()
assert 'ep0_write' in raw and 'ep0_read' in raw
assert 'devnum' in raw and 'presenter' in raw
qual=' '.join(articles['qual.virtual-usb.current']['invariants']).lower()
assert 'ebusy' in qual and 'not accepted' in qual
deps=' '.join(articles['vusb.dependency-authority']['invariants']).lower()
assert 'find ... | head -1' in deps and 'rexx_path' in deps
trust=' '.join(articles['vusb.whole-device-trust']['invariants']).lower()
assert 'separate claims' in trust and 'unexpected keyboard/mouse' in trust
ops=' '.join(articles['ops.virtual-usb.continuation']['procedure']).lower()
assert 'powered soc' in ops and 'browser/webauthn' in ops and 'hid class 03' in ops
corpus=json.loads((pack/'corpora'/'virtual-usb.continuity.json').read_text())
assert len(corpus['records']) >= 20
ids={r['id'] for r in corpus['records']}
for rid in ['baseline','raw-direction','stale-generation','dev8-invalid','dev9-live','dependency-authority','whole-device','hardware','production']:
    assert rid in ids
print(f"PASS Virtual USB sphere structure articles={len(articles)} continuity_records={len(corpus['records'])}")
print("PASS Raw Gadget generation, FIDO boundary, dependency authority and whole-device trust invariants")
PY
