#!/bin/sh
set -eu
ROOT=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
. "$ROOT/tests/python_env.sh"
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/pack" "$TMP/src/tests"

cat > "$TMP/pack/00-sphere-parent.json" <<'JSON'
{"kind":"sphere","id":"parent","version":"0.1","title":"Parent","access_policy":"test-access"}
JSON
cat > "$TMP/pack/01-sphere-child.json" <<'JSON'
{"kind":"sphere","id":"child","version":"0.1","title":"Child","access_policy":"test-access","inherits_services_from":["parent"]}
JSON
cat > "$TMP/pack/02-policy.json" <<'JSON'
{"kind":"access-policy","id":"test-access","version":"0.1","rules":[{"effect":"allow","roles":["llm"],"actions":["read","exec"],"resource":"*"}]}
JSON
cat > "$TMP/pack/03-parent-service.json" <<'JSON'
{"kind":"service","id":"parent.locate","version":"0.1","rank":10,"capabilities":["executable.locate"],"implementation":"builtin.executable.locate","operations":["exec"],"spheres":["parent"]}
JSON
cat > "$TMP/pack/04-corpus.json" <<'JSON'
{"kind":"corpus","id":"child.facts","sphere":"child","title":"Typed facts","records":[{"opcode":"5D","mnemonic":"D","text":"Divide"},{"topic":"precision","rule":"50 digits plus guard digits"}]}
JSON

# Explicit inheritance makes the parent-scoped service visible in child.
"$ROOT/gopher" --pack "$ROOT/packs/core" --pack "$TMP/pack" context child --full > "$TMP/context.json"
"$PYTHON" - "$TMP/context.json" <<'PY'
import json,sys
j=json.load(open(sys.argv[1]))
assert j['operation_status']['rc']==0
assert j['result']['inherits_services_from']==['parent']
caps={x['id']:x for x in j['result']['capabilities']}
assert 'executable.locate' in caps
assert 'parent.locate' in {x['service'] for x in caps['executable.locate']['services']}
PY

# Exact typed field lookup wins.
"$ROOT/gopher" --pack "$ROOT/packs/core" --pack "$TMP/pack" lookup opcode=5D --sphere child > "$TMP/exact.json"
"$PYTHON" - "$TMP/exact.json" <<'PY'
import json,sys
j=json.load(open(sys.argv[1]))
assert j['operation_status']=={'rc':0,'class':'FOUND'}
assert j['result']['match_kind']=='EXACT_FIELD'
assert j['result']['fallback_used'] is False
assert j['result']['hits'][0]['data']['mnemonic']=='D'
PY

# If no exact field value exists, bounded text fallback is explicit.
"$ROOT/gopher" --pack "$ROOT/packs/core" --pack "$TMP/pack" lookup topic='50 digits' --sphere child > "$TMP/fallback.json"
"$PYTHON" - "$TMP/fallback.json" <<'PY'
import json,sys
j=json.load(open(sys.argv[1]))
assert j['operation_status']['rc']==0
assert j['result']['match_kind']=='TEXT_FALLBACK'
assert j['result']['fallback_used'] is True
PY

# Positive terminal states added after early engine versions must carry rc=0.
printf '# Changelog\n## v0.15-dev1\n' > "$TMP/src/CHANGELOG.md"
printf '#!/bin/sh\nexit 0\n' > "$TMP/src/tests/run.sh"
chmod +x "$TMP/src/tests/run.sh"
"$ROOT/gopher" --profile oorexx package stage --in "$TMP/src" --to "$TMP/stage" > "$TMP/staged.json"
"$ROOT/gopher" --profile oorexx package check --in "$TMP/stage" --version v0.15-dev1 > "$TMP/ready.json"
"$ROOT/gopher" --profile oorexx exec dogfood.escape.record task=rc-test reason=qualification > "$TMP/recorded.json"
"$PYTHON" - "$TMP/staged.json" "$TMP/ready.json" "$TMP/recorded.json" <<'PY'
import json,sys
want=['STAGED','READY','RECORDED']
for fn,cls in zip(sys.argv[1:],want):
    j=json.load(open(fn)); assert j['operation_status']=={'rc':0,'class':cls},(fn,j['operation_status'])
PY

echo 'PASS ALL LLM GOPHER v0.15 SPHERE/LOOKUP/RC TESTS'
