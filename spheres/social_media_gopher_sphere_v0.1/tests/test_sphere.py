#!/usr/bin/env python3
import pathlib,json
b=pathlib.Path(__file__).resolve().parents[1]
root=json.loads((b/'packs/social-media/00-sphere.json').read_text())
assert root['kind']=='sphere' and root['id']=='social-media'
policy=json.loads((b/'packs/social-media/01-access-policy.json').read_text())
assert policy['id']==root['access_policy']
articles={}
for file in (b/'packs/social-media/articles').glob('*.json'):
    article=json.loads(file.read_text())
    assert article['kind']=='article' and article['sphere']=='social-media'
    assert article['id'] not in articles and article['provenance']
    articles[article['id']]=article
assert len(articles)==11 and set(root['start_here'])==set(articles)
for p in (b/'packs/social-media/corpora').glob('*.json'):
    data=json.loads(p.read_text())
    assert data['kind']=='corpus' and data['sphere']=='social-media' and data['records']
print("PASS 11 source-anchored social media Gopher articles")
