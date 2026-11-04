#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
python3 - "$ROOT" <<'PY2'
import json, pathlib, sys
root=pathlib.Path(sys.argv[1]); pack=root/'packs'/'legal-effect'
sphere=json.loads((pack/'00-sphere.json').read_text()); profile=json.loads((root/'profiles'/'legal-effect.json').read_text())
assert sphere['id']=='legal-effect' and sphere['version']=='0.1'
assert profile['id']=='legal-effect' and profile['version']=='0.1'
articles={json.loads(p.read_text())['id']:json.loads(p.read_text()) for p in (pack/'articles').glob('*.json')}
required={'le.overview','le.authority-boundary','le.interrogation-pipeline','le.source-provenance','le.intention-discovery','le.compiler-bridge','le.lifecycle-invalidation','le.counterfactual-boundary','le.tests-and-adversaries','qual.legal-current','ref.legal-sources'}
assert required <= set(articles)
for aid in sphere['start_here']: assert aid in articles, aid
for aid in required: assert articles[aid].get('provenance'), aid
assert 'not an llm opinion' in articles['le.overview']['title'].lower()
text=' '.join(articles['le.compiler-bridge']['invariants']).lower(); assert 'cryptographicallyverified' in text.replace('~','') and 'legalrulecompiler' in text.replace('~','') and 'legalpredicate' in text
text=' '.join(articles['le.authority-boundary']['invariants']).lower(); assert 'compiler/certification' in text and 'institutional policy' in text
text=' '.join(articles['le.intention-discovery']['invariants']).lower(); assert 'unchanged legal examination state' in text and 'ready' in text
text=' '.join(articles['le.lifecycle-invalidation']['invariants']).lower(); assert 'stale' in text and 'superseded' in text
gloss=json.loads((pack/'corpora'/'legal-effect.glossary.json').read_text()); assert len(gloss['records']) >= 18
cont=json.loads((pack/'corpora'/'legal-effect.continuity.json').read_text()); assert len(cont['records']) >= 24
for p in root.rglob('*.json'): json.loads(p.read_text())
print('PASS legal-effect sphere structure, authority boundaries, provenance, glossary and continuity corpus')
PY2
