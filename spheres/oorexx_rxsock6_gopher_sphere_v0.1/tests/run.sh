#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
python3 - "$ROOT" <<'PY'
import json, pathlib, sys
root=pathlib.Path(sys.argv[1])
pack=root/'packs'/'rxsock6'
sphere=json.loads((pack/'00-sphere.json').read_text())
profile=json.loads((root/'profiles'/'rxsock6.json').read_text())
assert sphere['id']=='rxsock6' and sphere['version']=='0.1'
assert profile['id']=='rxsock6' and 'packs/rxsock6' in profile['packs']
articles={}
for p in (pack/'articles').glob('*.json'):
    o=json.loads(p.read_text()); articles[o['id']]=o
required={'rxsock6.current','rxsock6.multicast-boundary','qual.rxsock6.current','ops.rxsock6.continuation'}
assert required <= set(articles)
assert set(sphere['start_here']) <= set(articles)
for aid in required:
    assert articles[aid].get('provenance'), aid
    for e in articles[aid]['provenance']:
        assert len(e.get('sha256',''))==64 and e.get('member') and e.get('line_start') and e.get('line_end')
text=' '.join(articles['rxsock6.current']['invariants']).lower()
assert 'sibling provider' in text and 'socketprovider.cls' in text and 'inet6address' in text
text=' '.join(articles['rxsock6.multicast-boundary']['invariants']).lower()
assert 'rfc 3678' in text and 'mldv2' in text and 'host' in text
text=' '.join(articles['ops.rxsock6.continuation']['invariants']).lower()
assert 'do not reconstruct' in text and 'do not relabel' in text
print(f"PASS RxSock6 sphere structure articles={len(articles)}")
print("PASS sibling-provider, object-preservation, multicast and source-sync invariants")
PY
