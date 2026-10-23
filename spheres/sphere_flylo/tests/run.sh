#!/usr/bin/env bash
set -euo pipefail
ROOT=$(cd "$(dirname "$0")/.." && pwd)
GOPHER=${GOPHER:-/mnt/data/gopher19/llm_gopher_v0.19-dev1/gopher}
"$GOPHER" --profile sphere-authoring sphere edit validate flylo --path "$ROOT" >/dev/null
python3 - "$ROOT" <<'PY'
import json,sys,pathlib
r=pathlib.Path(sys.argv[1])
s=json.load(open(r/'packs/flylo/00-sphere.json'))
assert s['version']=='0.3'
for article in ['flylo.current-baseline','flylo.mvs-backend-validation','flylo.authority-map','flylo.ui-regression-lessons','flylo.continuation']:
    assert article in s['start_here'], article
b=json.load(open(r/'packs/flylo/articles/flylo.current-baseline.json'))
assert b['baseline']['release']=='flylo_v0.4.11.zip'
assert b['baseline']['launcher']=='./flylo'
assert b['baseline']['mvs_backend_validation']=='examples/flylo_mvs_backend_v0.1'
m=json.load(open(r/'packs/flylo/articles/flylo.mvs-backend-validation.json'))
text=json.dumps(m).lower()
for x in ['operational path validity','ruleset-at-issue','one 3270 session','blank screen','ifox00','flctl']:
    assert x in text, x
u=json.load(open(r/'packs/flylo/articles/flylo.ui-regression-lessons.json'))
text=json.dumps(u).lower()
for x in ['passengercount','pax','fail closed','shared wire ui']:
    assert x in text, x
print('PASS flylo sphere v0.3 contract')
PY
