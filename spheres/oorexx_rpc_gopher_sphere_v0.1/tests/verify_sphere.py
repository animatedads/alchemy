#!/usr/bin/env python3
"""Minimal structural and provenance checks; not a Gopher semantic validator."""
import argparse
import hashlib
import json
from pathlib import Path
from zipfile import ZipFile

ROOT = Path(__file__).resolve().parent.parent

def digest(data):
    return hashlib.sha256(data).hexdigest()

def verify(archive_root=None):
    data = {}
    for path in ROOT.rglob('*.json'):
        data[path.relative_to(ROOT).as_posix()] = json.loads(path.read_text(encoding='utf-8'))
    sphere = data['packs/rpc-invocation/00-sphere.json']
    profile = data['profiles/rpc-invocation.json']
    ledger = data['SOURCE_ARCHIVES.json']
    assert sphere['kind']=='sphere' and sphere['id']=='rpc-invocation' and sphere['version']==profile['version']=='0.1.1'
    assert 'packs/rpc-invocation' in profile['packs']
    assert sphere['access_policy']==data['packs/rpc-invocation/01-access-policy.json']['id']
    article_paths = sorted(p for p in data if '/articles/' in p)
    assert len(article_paths)==11
    articles = {data[p]['id']:data[p] for p in article_paths}
    assert set(sphere['start_here']).issubset(articles)
    sections = {a['id'] for a in sphere['sections']}
    assert len(set(articles))==len(article_paths)
    for id_,a in articles.items():
        assert a['kind']=='article' and a['sphere']==sphere['id'] and a['section'] in sections
        assert a['summary'] and a['invariants'] and a['provenance']
        for rel in a.get('related',[]):
            assert rel in articles, (id_, rel)
        for p in a['provenance']:
            rec=ledger['artifacts'][p['artifact']]
            assert p['sha256']==rec['sha256']
            assert p['member_sha256']==rec['member_sha256']
    corpus=data['packs/rpc-invocation/corpora/rpc-invocation.continuity.json']
    assert corpus['kind']=='corpus' and corpus['sphere']==sphere['id'] and len(corpus['records'])>=10
    assert 'rpc.grpc' in articles and 'rpc.callbacks' in articles and 'rpc.https-ingress' in articles
    reg = articles['rpc.registry']
    assert any('registerMethod' in x for x in reg['api'])
    assert any('registerCallbackMethod' in x for x in reg['api'])
    grpc = articles['rpc.grpc']
    assert any('NOT' in x or 'unimplemented' in x for x in grpc['invariants'])
    for name, rec in ledger['artifacts'].items():
        assert len(rec['sha256'])==len(rec['member_sha256'])==64
        int(rec['sha256'], 16); int(rec['member_sha256'], 16)
        if archive_root is not None:
            archive=archive_root/name
            assert digest(archive.read_bytes())==rec['sha256'], name
            with ZipFile(archive) as z:
                assert digest(z.read(rec['member']))==rec['member_sha256'], rec['member']
    m = ROOT/'qualification/MANIFEST.sha256'
    entries = dict((line.split('  ',1)[1],line.split('  ',1)[0]) for line in m.read_text().splitlines())
    excluded={'qualification/MANIFEST.sha256'}
    expected={p.relative_to(ROOT).as_posix() for p in ROOT.rglob('*') if p.is_file()}-excluded
    assert set(entries)==expected, (sorted(expected-set(entries)),sorted(set(entries)-expected))
    for path, checksum in entries.items():
        assert digest((ROOT/path).read_bytes())==checksum, path
    print(f'PASS RPC sphere v0.1: {len(article_paths)} articles, {len(corpus["records"])} continuity records, {len(expected)} hashed files' + (' + exact source archives' if archive_root else ''))

if __name__=='__main__':
    ap=argparse.ArgumentParser()
    ap.add_argument('--archive-root',type=Path)
    args=ap.parse_args()
    verify(args.archive_root)
