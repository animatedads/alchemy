#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SOURCE_ZIP="${QUEUE_TRANSPORT_SOURCE_ZIP:-/mnt/data/oorexx_queue_fabric_v0.9-dev5.zip}"
python3 - "$ROOT" "$SOURCE_ZIP" <<'PY'
import json, pathlib, sys, hashlib, zipfile
root=pathlib.Path(sys.argv[1])
source=pathlib.Path(sys.argv[2])
pack=root/'packs'/'queue-transport'
sphere=json.loads((pack/'00-sphere.json').read_text())
profile=json.loads((root/'profiles'/'queue-transport.json').read_text())
policy=json.loads((pack/'01-access-policy.json').read_text())
assert sphere['id']=='queue-transport'
assert sphere['version']=='0.1'
assert sphere.get('inherits_services_from')==['oorexx']
assert profile['id']=='queue-transport'
assert profile['version']=='0.1'
assert profile['packs']==['packs/core','packs/oorexx','packs/queue-transport']
assert policy['id']=='queue-transport-access'
assert {'read','exec'} <= set(policy['rules'][0]['actions'])
articles={}
for p in (pack/'articles').glob('*.json'):
    o=json.loads(p.read_text()); articles[o['id']]=o
required={
 'qt.current','qt.boundary','qt.admission-order','qt.ip-policy','qt.peer-authentication',
 'qt.session-crypto','qt.secure-frames','qt.connection-lifecycle','qt.replay-idempotence',
 'qt.failure-semantics','qt.observability','qt.oci-two-node','qt.allocator-seam',
 'qt.secret-authority','qt.forward-secrecy','qt.version-boundary','qt.failover-health',
 'qual.queue-transport.current','ref.queue-transport.sources'
}
assert required == set(articles), (required-set(articles), set(articles)-required)
for aid in sphere['start_here']: assert aid in articles, aid
corpora={}
for p in (pack/'corpora').glob('*.json'):
    o=json.loads(p.read_text()); corpora[o['id']]=o
assert set(corpora)=={'queue-transport-glossary','queue-transport-continuity'}
assert len(corpora['queue-transport-glossary']['records']) >= 18
assert len(corpora['queue-transport-continuity']['records']) >= 12
expected_sha='05b3cbc92aff353dc3a44eb0373d7efb1e49a5e81071892b410a8b8f63fa2262'
assert source.is_file(), source
actual=hashlib.sha256(source.read_bytes()).hexdigest()
assert actual==expected_sha, (actual,expected_sha)
with zipfile.ZipFile(source) as z:
    names=set(z.namelist())
    for oid,o in list(articles.items())+list(corpora.items()):
        prov=o.get('provenance',[])
        assert prov, f'no provenance {oid}'
        for pr in prov:
            assert pr['artifact']=='oorexx_queue_fabric_v0.9-dev5.zip', oid
            assert pr['sha256']==expected_sha, oid
            assert pr['member'] in names, (oid,pr['member'])
            raw=z.read(pr['member']).decode('utf-8',errors='replace').splitlines()
            if 'line_start' in pr: assert 1 <= pr['line_start'] <= len(raw), (oid,pr)
            if 'line_end' in pr: assert pr.get('line_start',1) <= pr['line_end'] <= len(raw), (oid,pr,len(raw))
text=lambda aid: (articles[aid].get('summary','')+' '+' '.join(articles[aid].get('invariants',[]))).lower()
assert 'before hello' in text('qt.admission-order')
assert 'admission fact' in text('qt.peer-authentication')
assert 'exact canonical' in text('qt.ip-policy')
assert 'direction-separated' in text('qt.session-crypto')
assert 'authentication failure must stop processing before decryption' in text('qt.secure-frames')
assert 'one-command/response-per-connection' in text('qt.connection-lifecycle')
assert 'transferid' in text('qt.replay-idempotence')
assert '0.0.0.0/0' in text('qt.oci-two-node')
assert 'hard eligibility' in text('qt.allocator-seam')
assert 'secret broker' in text('qt.secret-authority')
assert 'does not provide forward secrecy' in text('qt.forward-secrecy')
assert 'not a sealed/released' in text('qt.current')
print('PASS Queue Transport sphere structure, provenance, doctrine and source-bound line ranges')
PY
