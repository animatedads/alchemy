#!/usr/bin/env python3
from pathlib import Path
import json
p=Path(__file__).resolve().parents[1]
objects=[(f,json.loads(f.read_text())) for f in p.rglob('*.json')]
s=json.loads((p/'packs/dynamic-story/00-sphere.json').read_text())
assert s['kind']=='sphere' and s['id']=='dynamic-story'
assert json.loads((p/'profiles/dynamic-story.json').read_text())['packs'][-1]=='packs/dynamic-story'
articles=[x for f,x in objects if x.get('kind')=='article']
assert len(articles)==7
assert set(s['start_here'])=={x['id'] for x in articles}
assert all(x['invariants'] and x['provenance'] and x['sphere']==s['id'] for x in articles)
assert (p/'qualification/QUALIFICATION.md').exists()
print('PASS dynamic-story sphere structure: 7 articles')
