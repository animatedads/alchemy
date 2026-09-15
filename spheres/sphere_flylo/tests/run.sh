#!/usr/bin/env bash
set -euo pipefail
ROOT=$(cd "$(dirname "$0")/.." && pwd)
GOPHER=${GOPHER:-/mnt/data/gopher19/llm_gopher_v0.19-dev1/gopher}
"$GOPHER" --profile sphere-authoring sphere edit validate flylo --path "$ROOT" >/dev/null
python3 - "$ROOT" <<'PY'
import json,sys,pathlib
r=pathlib.Path(sys.argv[1])
s=json.load(open(r/'packs/flylo/00-sphere.json'))
assert 'flylo.current-baseline' in s['start_here']
b=json.load(open(r/'packs/flylo/articles/flylo.current-baseline.json'))
assert b['baseline']['release']=='flylo_v0.4.11.zip'
assert b['baseline']['launcher']=='./flylo'
u=json.load(open(r/'packs/flylo/articles/flylo.ui-regression-lessons.json'))
text=json.dumps(u).lower()
for x in ['passengercount','pax','fail closed','shared wire ui']:
    assert x in text, x
print('PASS flylo sphere contract')
PY
