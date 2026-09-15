#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
python3 - "$ROOT" <<'PY'
import hashlib, json, pathlib, sys
root=pathlib.Path(sys.argv[1]); pack=root/'packs'/'unix-socket'
sphere=json.loads((pack/'00-sphere.json').read_text())
profile=json.loads((root/'profiles'/'unix-socket.json').read_text())
assert sphere['id']=='unix-socket' and sphere['version']=='0.1'
assert profile['id']=='unix-socket' and profile['version']=='0.1'
assert 'packs/core' in profile['packs'] and 'packs/unix-socket' in profile['packs']
articles={}
for p in (pack/'articles').glob('*.json'):
    o=json.loads(p.read_text()); articles[o['id']]=o
required={
'usock.current','usock.stock-socket-limitation','usock.semantic-binding-split','usock.address-model',
'usock.descriptor-ownership','usock.ancillary-data','usock.credentials','usock.poll-nonblocking',
'usock.pathname-security','usock.abi-authority','usock.native-scalars-vs-layout','usock.portability',
'usock.migration-history','ref.unix-socket.sources','qual.unix-socket.current','ops.unix-socket.continuation'}
assert required <= set(articles), required-set(articles)
assert set(sphere['start_here']) <= set(articles)
USHA='aea3f193e910b216b051b046cc9ea695089e7ed67013a1a1a412d1324199e326'
FSHA='25a7b258b7920c355b96f19807515d6fb6e419687714396589b054a7029ab465'
for aid in required:
    prov=articles[aid].get('provenance',[])
    assert prov, f'no provenance: {aid}'
    for e in prov:
        assert len(e.get('sha256',''))==64 and e.get('member'), (aid,e)
assert any(e['sha256']==FSHA for e in articles['usock.semantic-binding-split']['provenance'])
assert any(e['sha256']==FSHA for e in articles['usock.native-scalars-vs-layout']['provenance'])
assert any(e['sha256']==USHA for e in articles['qual.unix-socket.current']['provenance'])
text=(articles['usock.stock-socket-limitation']['summary']+' '+' '.join(articles['usock.stock-socket-limitation']['invariants'])).lower()
assert 'af_unix' in text and 'socket.cls' in text and ('not a sockaddr_un contract' in text or 'does not expose' in text)
text=' '.join(articles['usock.semantic-binding-split']['invariants']).lower()
assert 'foreign runtime' in text and 'native shared library' in text
text=' '.join(articles['usock.ancillary-data']['invariants']).lower()
assert 'partial capability set' in text and 'raw pointer' in text
text=' '.join(articles['usock.credentials']['invariants']).lower()
assert 'not themselves authorize' in text
text=' '.join(articles['usock.abi-authority']['invariants']).lower()
assert ('before dlopen' in text or 'before the native provider is opened' in text) and 'aarch64' in text
text=' '.join(articles['usock.native-scalars-vs-layout']['invariants']).lower()
assert 'does not make a struct layout architecture-neutral' in text
text=' '.join(articles['ops.unix-socket.continuation']['invariants']).lower()
assert 'do not modify stock socket.cls' in text and 'do not reintroduce' in text
corpus=json.loads((pack/'corpora'/'unix-socket.continuity.json').read_text())
assert len(corpus['records']) >= 20
ids={r['id'] for r in corpus['records']}
for rid in ['baseline','binding','stock','rights','ctrunc','credentials','abi','native-scalars','profile','forcing','next']:
    assert rid in ids
assert corpus.get('provenance')
service=json.loads((pack/'services'/'unix-socket.oorexx.source.examine.json').read_text())
assert 'source.oorexx.examine' in service['capabilities']
print(f"PASS Unix Socket sphere structure articles={len(articles)} continuity_records={len(corpus['records'])}")
print('PASS doctrine negative controls, ownership, credential, ABI and provenance invariants')
PY
