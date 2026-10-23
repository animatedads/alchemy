#!/usr/bin/env python3
"""Static Font Manager sphere consistency check; no Gopher runtime required."""
import json
from pathlib import Path
root=Path(__file__).resolve().parents[1]
pack=root/'packs/font-manager'
meta=json.loads((pack/'00-sphere.json').read_text())
policy=json.loads((pack/'01-access-policy.json').read_text())
profile=json.loads((root/'profiles/font-manager.json').read_text())
articles=[json.loads(p.read_text()) for p in sorted((pack/'articles').glob('*.json'))]
ids={a['id'] for a in articles}
assert len(ids)==6
assert meta['kind']=='sphere' and meta['id']=='font-manager'
assert policy['kind']=='access-policy' and policy['id']==meta['access_policy']
assert profile['kind']=='profile' and profile['id']==meta['id'] and 'packs/font-manager' in profile['packs']
assert set(meta['start_here'])==ids
for article in articles:
    assert article['kind']=='article' and article['sphere']==meta['id']
    assert set(article.get('related',[]))<=ids
    for p in article.get('provenance',[]):
        assert len(p['sha256'])==64 and p.get('artifact') and p.get('member') and p.get('claim')
print('PASS: font-manager sphere metadata, six articles, provenance and cross-references')
