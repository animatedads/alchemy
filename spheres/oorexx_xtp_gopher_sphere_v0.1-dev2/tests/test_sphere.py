#!/usr/bin/env python3
"""Standalone validation of XTP Gopher sphere; no runtime or network needed."""
from pathlib import Path
import json,hashlib,re
root=Path(__file__).resolve().parents[1]
read=lambda p:json.loads((root/p).read_text(encoding='utf-8'))
sphere=read('packs/xtp/00-sphere.json')
profile=read('profiles/xtp.json')
policy=read('packs/xtp/01-access-policy.json')
manifest=read('SOURCE_MANIFEST.json')
articles={p.stem:json.loads(p.read_text(encoding='utf-8')) for p in sorted((root/'packs/xtp/articles').glob('*.json'))}
assert sphere['id']=='xtp' and sphere['kind']=='sphere'
assert profile['id']=='xtp' and 'packs/xtp' in profile['packs']
assert policy['id']==sphere['access_policy'] and all('write' not in x['actions'] for x in policy['rules'])
assert len(articles)>=12,(len(articles),list(articles))
for name,item in articles.items():
    assert item['id']==name and item['sphere']=='xtp' and item['kind']=='article'
    assert item['section'] in [s['id'] for s in sphere['sections']]
    assert item.get('provenance'),name
    assert item.get('invariants'),name
    for dep in item.get('related',[]): assert dep in articles,(name,dep)
    for p in item['provenance']:
        assert len(p['sha256'])==64 and re.fullmatch('[a-f0-9]{64}',p['sha256']),p
        assert any(s['sha256']==p['sha256'] and s['artifact']==p['artifact'] for s in manifest['sources'].values()),p
for entry in sphere['start_here']: assert entry in articles,entry
records=read('packs/xtp/corpora/xtp.continuity.json')
assert records['sphere']=='xtp' and records['kind']=='corpus' and len(records['records'])>=10
alltext='\n'.join(p.read_text(encoding='utf-8') for p in (root/'packs').rglob('*.json'))
for needle in ('xtp.provision','2-of-2','2-of-3','CAP_NET_RAW','KEY','ED209','ROUTE/XROUTE','SAMPLE/AGGREGATE','LDAP'):
    assert needle in alltext,needle
assert 'NOT QUALIFIED' in (root/'qualification/QUALIFICATION.md').read_text()
assert len(manifest['sources'])>=8
print('PASS XTP sphere: '+str(len(articles))+' articles, '+str(len(records['records']))+' continuity records, '+str(len(manifest['sources']))+' pinned source archives')
