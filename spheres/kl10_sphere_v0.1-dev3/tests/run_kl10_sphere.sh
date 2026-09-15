#!/usr/bin/env bash
set -euo pipefail
ROOT=$(cd "$(dirname "$0")/.." && pwd)
cd "$ROOT"

python_cmd=${LLM_GOPHER_PYTHON:-python3}

run_json() {
  "$@" > /tmp/gopher-kl10-test.json
  "$python_cmd" - /tmp/gopher-kl10-test.json <<'PY'
import json,sys
p=json.load(open(sys.argv[1]))
assert p['tool_status']['class']=='OK', p
print(p['operation_status']['class'])
PY
}

st=$(run_json ./gopher --profile kl10 context kl10)
[ "$st" = OPENED ]

./gopher --profile kl10 help kl10 > /tmp/gopher-kl10-help.json
"$python_cmd" - /tmp/gopher-kl10-help.json <<'PY'
import json,sys
p=json.load(open(sys.argv[1]))
r=p['result']
assert r['sphere']=='kl10'
ids={x['id'] for x in r['articles']}
for x in ('kl10.start-here','kl10.architecture','kl10.tops20.paging','kl10.boot-debugging','kl10.current-continuation'):
    assert x in ids, (x,ids)
print('PASS help')
PY

./gopher --profile kl10 search PNRCOD --sphere kl10 > /tmp/gopher-kl10-search.json
"$python_cmd" - /tmp/gopher-kl10-search.json <<'PY'
import json,sys
p=json.load(open(sys.argv[1]))
assert p['operation_status']['class']=='FOUND', p
hits=p['result']['hits']
assert any(h['data'].get('id')=='tops20.v7.postld' for h in hits), hits
print('PASS PNRCOD corpus')
PY

./gopher --profile kl10 search BLT --sphere kl10 > /tmp/gopher-kl10-blt.json
"$python_cmd" - /tmp/gopher-kl10-blt.json <<'PY'
import json,sys
p=json.load(open(sys.argv[1]))
assert p['operation_status']['class']=='FOUND', p
ids={h['data'].get('id') for h in p['result']['hits']}
assert 'kl10.production-microcode.blt' in ids, ids
assert 'dec.processor-reference.1982' in ids, ids
print('PASS BLT corpus')
PY

./gopher --profile kl10 search 041342 --sphere kl10 > /tmp/gopher-kl10-041342.json
"$python_cmd" - /tmp/gopher-kl10-041342.json <<'PY'
import json,sys
p=json.load(open(sys.argv[1]))
assert p['operation_status']['class']=='FOUND', p
hits=p['result']['hits']
assert any(h['data'].get('id')=='kl10.continuation.2026-09-02.041342' for h in hits), hits
print('PASS current continuation corpus')
PY

./gopher --profile kl10 open kl10.start-here > /tmp/gopher-kl10-open.json
"$python_cmd" - /tmp/gopher-kl10-open.json <<'PY'
import json,sys
p=json.load(open(sys.argv[1]))
assert p['operation_status']['class']=='OPENED', p
assert len(p['result'].get('invariants',[])) >= 5
print('PASS start-here')
PY

# The KL10 sphere is an ooRexx implementation workspace. Its profile loads
# the ooRexx language/service pack, and the sphere explicitly inherits ooRexx
# service visibility so callers may retain KL10 destination authority.
./gopher --profile kl10 examine source Sample.cls --in examples/Sample.cls > /tmp/gopher-kl10-oorexx-default.json
"$python_cmd" - /tmp/gopher-kl10-oorexx-default.json <<'PY'
import json,sys
p=json.load(open(sys.argv[1]))
assert p['tool_status']['class']=='OK', p
assert p['operation_status']['class']=='EXAMINED', p
route=p.get('evidence',{}).get('examine_route',{})
assert route.get('requested_capability')=='source.oorexx.examine', route
assert route.get('service')=='oorexx.source.examine', route
print('PASS ooRexx source examiner loaded by KL10 profile')
PY

./gopher --profile kl10 examine source Sample.cls --in examples/Sample.cls --sphere kl10 > /tmp/gopher-kl10-oorexx-inherited.json
"$python_cmd" - /tmp/gopher-kl10-oorexx-inherited.json <<'PY'
import json,sys
p=json.load(open(sys.argv[1]))
assert p['tool_status']['class']=='OK', p
assert p['operation_status']['class']=='EXAMINED', p
route=p.get('evidence',{}).get('examine_route',{})
assert route.get('requested_capability')=='source.oorexx.examine', route
assert route.get('service')=='oorexx.source.examine', route
print('PASS inherited ooRexx source examiner under KL10 authority')
PY

./gopher --profile kl10 search CST_AGE_ZERO --sphere kl10 > /tmp/gopher-kl10-cst-age.json
"$python_cmd" - /tmp/gopher-kl10-cst-age.json <<'PY'
import json,sys
p=json.load(open(sys.argv[1]))
assert p['operation_status']['class']=='FOUND', p
hits=p['result']['hits']
r=[h['data'] for h in hits if h['data'].get('id')=='kl10.continuation.2026-09-02.pre041342-comparison']
assert r, hits
facts=' '.join(r[0].get('facts',[]))
assert 'event oracle' in facts
assert 'APR flags are 002000 rather than 000000' in facts
print('PASS historical 041342 event/state distinction')
PY

echo 'PASS KL10 GOPHER SPHERE'
