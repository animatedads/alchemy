#!/bin/sh
set -eu
ROOT=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
cd "$ROOT"
sha256sum -c qualification/MANIFEST.sha256 >/dev/null
python3 - <<'PY'
import json
from pathlib import Path
root=Path('.')
paths=[
 root/'packs/cluster-object-memory/00-sphere.json',
 root/'packs/cluster-object-memory/01-access-policy.json',
 root/'packs/cluster-object-memory/articles/arch.cluster-object-memory.execution-follows-memory.json',
 root/'packs/cluster-object-memory/articles/ops.cluster-object-memory.continue.json',
 root/'packs/cluster-object-memory/corpora/cluster-object-memory.lessons.json',
 root/'profiles/cluster-object-memory.json'
]
for p in paths:
    json.loads(p.read_text())
text=(root/'packs/cluster-object-memory/articles/arch.cluster-object-memory.execution-follows-memory.json').read_text()
folded=text.lower()
for token in ['execution follows', 'move_uncertain', 'field_pass', 'durable remote receipt']:
    assert token in folded, token
print('PASS cluster-object-memory sphere static qualification')
PY
