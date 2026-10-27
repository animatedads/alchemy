#!/bin/sh
set -eu
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
python3 - "$ROOT" <<'PY'
import json, pathlib, sys
root=pathlib.Path(sys.argv[1])
files=list(root.glob('packs/management-intentions/*.json'))+list(root.glob('packs/management-intentions/articles/*.json'))+list(root.glob('profiles/*.json'))
for p in files:
    with p.open('r', encoding='utf-8') as f: json.load(f)
required={
 'arch.management-intentions.discovery',
 'arch.management-intentions.mvs',
 'arch.management-intentions.authority',
 'arch.management-intentions.cloud-control',
 'arch.management-intentions.relationships',
 'arch.management-intentions.instrumentation',
 'arch.management-intentions.networking',
 'ops.management-intentions.continue'}
seen=set()
for p in root.glob('packs/management-intentions/articles/*.json'):
    seen.add(json.loads(p.read_text())['id'])
missing=required-seen
if missing: raise SystemExit('missing articles: '+', '.join(sorted(missing)))
print('PASS management-intentions sphere v0.1 JSON/continuity inventory')
PY
