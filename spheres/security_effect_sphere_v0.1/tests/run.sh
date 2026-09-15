#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
python3 - "$ROOT" <<'PY'
import json, pathlib, sys
root=pathlib.Path(sys.argv[1]); pack=root/'packs'/'security-effect'
sphere=json.loads((pack/'00-sphere.json').read_text()); profile=json.loads((root/'profiles'/'security-effect.json').read_text())
assert sphere['id']=='security-effect' and sphere['version']=='0.1'
assert profile['id']=='security-effect' and profile['version']=='0.1'
articles={json.loads(p.read_text())['id']:json.loads(p.read_text()) for p in (pack/'articles').glob('*.json')}
required={'sec.overview','sec.evidence-action-scope','sec.cross-session-memory','sec.probes','sec.fixed-policy','ip.governance-lifecycle','ip.deployment-rollout','sec.review-referral','sec.permissions-boundary','sec.invocation-freshness','sec.commit-revalidation','ops.security-reasoning','qual.security-current','ref.security-sources'}
assert required <= set(articles)
for aid in sphere['start_here']: assert aid in articles, aid
for aid in required: assert articles[aid].get('provenance'), aid
text=(articles['sec.overview']['summary']+' '+' '.join(articles['sec.overview']['invariants'])).lower()
assert 'action' in text and 'runtime llm' in text
text=' '.join(articles['sec.permissions-boundary']['invariants']).lower(); assert 'grants no method authority' in text and 'permission allow cannot erase' in text
text=' '.join(articles['sec.commit-revalidation']['invariants']).lower(); assert 'initial security allow is not authority to commit later' in text and 'single-use' in text
cont=json.loads((pack/'corpora'/'security-effect.continuity.json').read_text()); assert len(cont['records']) >= 20
gloss=json.loads((pack/'corpora'/'security-effect.glossary.json').read_text()); assert len(gloss['records']) >= 12
print('PASS security-effect sphere structure, doctrine, provenance, glossary and continuity corpus')
PY
