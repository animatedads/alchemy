#!/usr/bin/env python3
import json,pathlib
root=pathlib.Path(__file__).resolve().parents[1]
items=list(root.rglob('*.json'))
for file in items:
    json.loads(file.read_text(encoding='utf-8'))
pack=root/'packs/website-publisher'
sphere=json.loads((pack/'00-sphere.json').read_text())
assert sphere['kind']=='sphere' and sphere['id']=='website-publisher'
profile=json.loads((root/'profiles/website-publisher.json').read_text())
assert 'packs/website-publisher' in profile['packs']
art=list((pack/'articles').glob('*.json'))
assert len(art)==6
ids={json.loads(f.read_text())['id'] for f in art}
assert set(sphere['start_here'])==ids
for f in art:
  a=json.loads(f.read_text())
  assert a['sphere']==sphere['id'] and a['version']=='0.1' and a['invariants'] and a['provenance']
ref=json.loads((root/'SOURCE_ARCHIVES.json').read_text())
assert len(ref['owned_files'])>=15
assert ref['nosqlserver_v090']['sha256']!='' and 'NOT qualified' in ref['nosqlserver_v091']['status']
print(f'PASS sphere: {len(art)} articles, {len(items)} JSON files, {len(ref["owned_files"])} provenance-locked source files')
