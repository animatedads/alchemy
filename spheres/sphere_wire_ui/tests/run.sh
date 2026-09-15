#!/usr/bin/env bash
set -euo pipefail
ROOT=$(cd "$(dirname "$0")/.." && pwd)
GOPHER=${GOPHER:-/mnt/data/gopher19/llm_gopher_v0.19-dev1/gopher}
"$GOPHER" --profile sphere-authoring sphere edit validate wire-ui --path "$ROOT" >/dev/null
python3 - "$ROOT" <<'PY'
import json,sys,pathlib
r=pathlib.Path(sys.argv[1])
s=json.load(open(r/'packs/wire-ui/00-sphere.json'))
assert 'wire-ui.authoritative-rows' in s['start_here']
a=json.load(open(r/'packs/wire-ui/articles/wire-ui.authoritative-rows.json'))
text=json.dumps(a)
for x in ['stable server-owned semantic identity','count','fail closed']:
    assert x.lower() in text.lower(), x
w=json.load(open(r/'packs/wire-ui/articles/wire-ui.workspace-authority.json'))
for x in ['query','scope','order','selection','result']:
    assert x in json.dumps(w).lower(), x
print('PASS wire-ui sphere contract')
PY
