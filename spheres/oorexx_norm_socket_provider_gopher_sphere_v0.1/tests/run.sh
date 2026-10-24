#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
python3 - "$ROOT" <<'PY'
import json,pathlib,sys
root=pathlib.Path(sys.argv[1]); pack=root/'packs'/'norm-socket-provider'
sphere=json.loads((pack/'00-sphere.json').read_text())
profile=json.loads((root/'profiles'/'norm-socket-provider.json').read_text())
assert sphere['id']=='norm-socket-provider' and sphere['version']=='0.1'
assert profile['id']=='norm-socket-provider' and profile['version']=='0.1'
articles={}
for p in (pack/'articles').glob('*.json'):
    o=json.loads(p.read_text()); articles[o['id']]=o
required={'norm.current','norm.boundary','norm.membership','norm.reliability','norm.qualification','norm.continuation'}
assert required <= set(articles), required-set(articles)
assert set(sphere['start_here']) <= set(articles)
sha='d997007d35c7527eb40d6d62516cee036ed2d1a27fb1edbe32bdf4389abcd231'
for aid in required:
    prov=articles[aid].get('provenance',[])
    assert prov and any(x.get('sha256')==sha for x in prov), aid
assert 'SocketSelector' in ' '.join(articles['norm.boundary']['invariants'])
assert 'SocketMulticastMembership' in ' '.join(articles['norm.membership']['invariants'])
assert 'paritySymbols=0' in ' '.join(articles['norm.reliability']['invariants'])
assert 'dev16' in ' '.join(articles['norm.qualification']['invariants'])
assert 'Event Runtime' in ' '.join(articles['norm.continuation']['invariants'])
print('PASS NORM socket-provider sphere structure and continuity invariants')
PY
