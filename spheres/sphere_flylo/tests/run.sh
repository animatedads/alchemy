#!/usr/bin/env bash
set -euo pipefail
ROOT=$(cd "$(dirname "$0")/.." && pwd)
GOPHER=${GOPHER:-/mnt/data/gopher19/llm_gopher_v0.19-dev1/gopher}
"$GOPHER" --profile sphere-authoring sphere edit validate flylo --path "$ROOT" >/dev/null
python3 - "$ROOT" <<'PY'
import json,sys,pathlib
r=pathlib.Path(sys.argv[1])
s=json.load(open(r/'packs/flylo/00-sphere.json'))
assert s['version']=='0.4'
for article in ['flylo.current-baseline','flylo.platform-integration','flylo.mvs-backend-validation','flylo.authority-map','flylo.ui-regression-lessons','flylo.continuation']:
    assert article in s['start_here'], article
b=json.load(open(r/'packs/flylo/articles/flylo.current-baseline.json'))
assert b['baseline']['release']=='flylo_v0.4.11.zip'
assert b['baseline']['launcher']=='./flylo'
assert b['baseline']['mvs_backend_validation']=='examples/flylo_mvs_backend_v0.1'
p=json.load(open(r/'packs/flylo/articles/flylo.platform-integration.json'))
pins={x['component']:(x['artifact'],x['sha256'],x['status']) for x in p['current_candidates']}
assert pins['terminal-machine'][0]=='oorexx_terminal_machine_v0.22-candidate16.zip'
assert pins['ldap-identity'][0]=='oorexx_ldap_identity_v0.1-dev22.zip'
assert pins['https-server'][0]=='oorexx_https_server_v0.4.8.zip'
assert all(v[2]=='QUALIFICATION_PENDING' for v in pins.values())
m=json.load(open(r/'packs/flylo/articles/flylo.mvs-backend-validation.json'))
text=json.dumps(m).lower()
for x in ['operational path validity','ruleset-at-issue','one 3270 session','blank screen','ifox00','flctl']:
    assert x in text, x
u=json.load(open(r/'packs/flylo/articles/flylo.ui-regression-lessons.json'))
text=json.dumps(u).lower()
for x in ['passengercount','pax','fail closed','shared wire ui']:
    assert x in text, x
print('PASS flylo sphere v0.4 contract')
PY
