#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
API_ROLLUP="${ALCHEMY_CORE_API_ROLLUP:-/mnt/data/oorexxapis(20260902-164832).zip}"
PRE2="${ALCHEMY_CORE_V06_PRE2:-/mnt/data/alchemy_oorexx_core_rollup_v0.6-pre2-source.zip}"
REQUAL="${ALCHEMY_CORE_V05_REQUAL:-/mnt/data/alchemy_oorexx_core_v0.5_r13196_requalification_20260901.txt}"
python3 - "$ROOT" "$API_ROLLUP" "$PRE2" "$REQUAL" <<'PY'
import io, json, hashlib, pathlib, sys, zipfile
root=pathlib.Path(sys.argv[1]); api=pathlib.Path(sys.argv[2]); pre2=pathlib.Path(sys.argv[3]); requal=pathlib.Path(sys.argv[4])
pack=root/'packs'/'alchemy-core'
sha={
 'api':'190c3e9f7b484cfccc3e0fa4fe7fe07e6f0d15838ae2024b028ccaffd9652830',
 'v05':'2238db47c130f5c71e825fb49c50037a2f41c910005d10bf2175483162606548',
 'objects':'7683ed56ea99097226ea2f13f73305fb49919ba2ec822df2253ccfff59c6c073',
 'crypto':'5ebcab81493287499719f98920cb190d37afc79992cb34c7772d5392f63b9b49',
 'pre2':'3b0a18732a6ec33fc55ac35cf4589fb931623796cd0d628062a83c2cfcac914b',
 'requal':'8301d9316817bf0b00bb913f6baf2a698525dcff07c149153c60497f3473a92e'
}
def digest_bytes(b): return hashlib.sha256(b).hexdigest()
def digest_file(p): return digest_bytes(p.read_bytes())
assert api.is_file(), api
assert digest_file(api)==sha['api'], (digest_file(api),sha['api'])
assert pre2.is_file(), pre2
assert digest_file(pre2)==sha['pre2'], (digest_file(pre2),sha['pre2'])
assert requal.is_file(), requal
assert digest_file(requal)==sha['requal'], (digest_file(requal),sha['requal'])
with zipfile.ZipFile(api) as az:
    nested={
      'alchemy_oorexx_core_rollup_v0.5.zip': az.read('current/alchemy_oorexx_core_rollup_v0.5.zip'),
      'alchemy_objects_v0.8.zip': az.read('current/alchemy_objects_v0.8.zip'),
      'oorexx_crypto_v0.8.3.zip': az.read('current/oorexx_crypto_v0.8.3.zip')
    }
    assert digest_bytes(nested['alchemy_oorexx_core_rollup_v0.5.zip'])==sha['v05']
    assert digest_bytes(nested['alchemy_objects_v0.8.zip'])==sha['objects']
    assert digest_bytes(nested['oorexx_crypto_v0.8.3.zip'])==sha['crypto']

sphere=json.loads((pack/'00-sphere.json').read_text())
profile=json.loads((root/'profiles'/'alchemy-core.json').read_text())
policy=json.loads((pack/'01-access-policy.json').read_text())
assert sphere['id']=='alchemy-core' and sphere['version']=='0.1'
assert sphere.get('inherits_services_from')==['oorexx']
assert profile['id']=='alchemy-core' and profile['version']=='0.1'
assert profile['packs']==['packs/core','packs/oorexx','packs/alchemy-core']
assert policy['id']=='alchemy-core-access'
assert {'read','exec'} <= set(policy['rules'][0]['actions'])
articles={}
for p in (pack/'articles').glob('*.json'):
    o=json.loads(p.read_text()); articles[o['id']]=o
required={
 'ac.current','ac.doctrine.model-first','ac.object-foundation','ac.package-model','ac.transport-boundary',
 'ac.repository-lease','ac.accepted-main','ac.semantic-identity','ac.execution','ac.publication',
 'ac.submission-protocol','ac.inbox','ac.evidence','ac.resident-service','ac.runtime-capsule',
 'ac.dependency-floor','ac.versioning','ac.v06-continuation','qual.alchemy-core.current','ref.alchemy-core.sources'
}
assert set(articles)==required, (required-set(articles),set(articles)-required)
for aid in sphere['start_here']: assert aid in articles, aid
corpora={}
for p in (pack/'corpora').glob('*.json'):
    o=json.loads(p.read_text()); corpora[o['id']]=o
assert set(corpora)=={'alchemy-core-glossary','alchemy-core-continuity'}
assert len(corpora['alchemy-core-glossary']['records'])>=20
assert len(corpora['alchemy-core-continuity']['records'])>=20

# Build artifact readers for canonical provenance.
zip_sources={
 'alchemy_oorexx_core_rollup_v0.5.zip': (sha['v05'], zipfile.ZipFile(io.BytesIO(nested['alchemy_oorexx_core_rollup_v0.5.zip']))),
 'alchemy_objects_v0.8.zip': (sha['objects'], zipfile.ZipFile(io.BytesIO(nested['alchemy_objects_v0.8.zip']))),
 'oorexx_crypto_v0.8.3.zip': (sha['crypto'], zipfile.ZipFile(io.BytesIO(nested['oorexx_crypto_v0.8.3.zip']))),
 'alchemy_oorexx_core_rollup_v0.6-pre2-source.zip': (sha['pre2'], zipfile.ZipFile(pre2)),
 'oorexxapis(20260902-164832).zip': (sha['api'], zipfile.ZipFile(api)),
}
plain_sources={
 'alchemy_oorexx_core_v0.5_r13196_requalification_20260901.txt': (sha['requal'], requal.read_bytes())
}
for oid,o in list(articles.items())+list(corpora.items()):
    prov=o.get('provenance',[])
    assert prov, f'no provenance {oid}'
    for pr in prov:
        artifact=pr['artifact']; expected=pr['sha256']; member=pr['member']
        if artifact in zip_sources:
            actual,z=zip_sources[artifact]
            assert actual==expected, (oid,artifact,actual,expected)
            assert member in set(z.namelist()), (oid,artifact,member)
            raw=z.read(member)
        elif artifact in plain_sources:
            actual,raw=plain_sources[artifact]
            assert actual==expected, (oid,artifact,actual,expected)
            assert member==artifact, (oid,artifact,member)
        else:
            raise AssertionError((oid,'unknown provenance artifact',artifact))
        if 'line_start' in pr or 'line_end' in pr:
            lines=raw.decode('utf-8',errors='replace').splitlines()
            a=pr.get('line_start',1); b=pr.get('line_end',a)
            assert 1 <= a <= b <= len(lines), (oid,artifact,member,a,b,len(lines))

text=lambda aid: (articles[aid].get('title','')+' '+articles[aid].get('summary','')+' '+' '.join(articles[aid].get('invariants',[]))).lower()
assert 'model the thing' in text('ac.doctrine.model-first')
assert 'does not resolve' in text('ac.transport-boundary') or 'not domain planning' in text('ac.transport-boundary')
assert 'dirty or stale' in text('ac.accepted-main')
assert 'ready.json' in text('ac.submission-protocol') and 'committed last' in text('ac.submission-protocol')
assert 'bootstrap_only_not_acceptance' in text('ac.dependency-floor')
assert 'malformed manifest' in text('ac.semantic-identity') and 'fail' in text('ac.semantic-identity')
assert 'terminal receipt' in text('ac.evidence') and 'idempot' in text('ac.evidence')
assert 'not rc' in text('ac.v06-continuation') or 'not accepted' in text('ac.v06-continuation')
assert sha['objects'] in text('ac.v06-continuation')
assert sha['crypto'] in text('ac.v06-continuation')
assert '15/15' in text('qual.alchemy-core.current') and '13/13' in text('qual.alchemy-core.current')
assert 'python' in text('ac.doctrine.model-first') and 'not the alchemy core architectural default' in text('ac.doctrine.model-first')
print('PASS Alchemy Core sphere structure, exact source hashes, provenance line ranges, doctrine and continuation gates')
PY
