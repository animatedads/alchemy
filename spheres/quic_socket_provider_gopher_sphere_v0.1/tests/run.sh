#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
python3 - "$ROOT" <<'PY'
import json,pathlib,sys
root=pathlib.Path(sys.argv[1]); pack=root/'packs'/'quic-socket-provider'
sphere=json.loads((pack/'00-sphere.json').read_text())
profile=json.loads((root/'profiles'/'quic-socket-provider.json').read_text())
assert sphere['id']=='quic-socket-provider' and sphere['version']=='0.1'
assert profile['id']=='quic-socket-provider' and profile['version']=='0.1'
articles={}
for p in (pack/'articles').glob('*.json'):
    o=json.loads(p.read_text()); articles[o['id']]=o
required={'quic.current','quic.boundary','quic.security','quic.multiplexing','quic.qualification','quic.continuation'}
assert required <= set(articles), required-set(articles)
assert set(sphere['start_here']) <= set(articles)
dev3='34a224252f33079cdbe78d4e5f6f122c0cdd6524364f92e95da36bc233b54749'
dev4='51464ddea2dec56557a8ea7f806fe8f54933da99527b249a67da2e74f3fde63b'
assert any(x.get('sha256')==dev4 for x in articles['quic.current'].get('provenance',[]))
assert any(x.get('sha256')==dev3 for x in articles['quic.current'].get('provenance',[]))
assert any(x.get('sha256')==dev4 for x in articles['quic.qualification'].get('provenance',[]))
assert any(x.get('sha256')==dev3 for x in articles['quic.qualification'].get('provenance',[]))
assert any(x.get('sha256')==dev4 for x in articles['quic.continuation'].get('provenance',[]))
for aid in {'quic.boundary','quic.security','quic.multiplexing'}:
    assert any(x.get('sha256')==dev3 for x in articles[aid].get('provenance',[])), aid
text=' '.join(articles['quic.boundary']['invariants'])
assert 'QuicSocketAddress' in text and 'SocketSelector' in text
text=' '.join(articles['quic.security']['invariants']).lower()
assert 'private key' in text and 'provider' in text
text=' '.join(articles['quic.multiplexing']['invariants'])
assert 'SocketStreamAdapter' in text and 'openStream' in text
text=' '.join(articles['quic.qualification']['invariants'])
assert 'NOT RUN' in text and 'SSL_STREAM_FLAG_NO_BLOCK' in text
text=' '.join(articles['quic.continuation']['invariants'])
assert 'HTTP/3' in text and 'COTS' in text and 'WANT_WRITE' in text
print('PASS QUIC socket-provider sphere dev3/live + dev4/development continuity invariants')
PY
