#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
G="$ROOT/gopher"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
. "$ROOT/tests/python_env.sh"
cat > "$TMP/sample.py" <<'PY'
from math import *
class Sample:
    def hello(self):
        return 1
    def hello(self):
        return 2
try:
    risky()
except:
    pass
PY
cat > "$TMP/sample.cls" <<'RX'
::requires "One.cls"
::requires "One.cls"
::class Sample public
::method hello
  return 1
::method hello
  return 2
::class Sample public
::method other
  return 3
RX
"$G" --profile oorexx rules check "$TMP/sample.py" --language python > "$TMP/py.json"
"$G" --profile oorexx rules check "$TMP/sample.cls" --language oorexx > "$TMP/rx.json"
"$PYTHON" - "$TMP/py.json" "$TMP/rx.json" <<'PY'
import json,sys
p=json.load(open(sys.argv[1])); r=json.load(open(sys.argv[2]))
assert p['operation_status']['class']=='BREACHED'
assert [x['rule'] for x in p['result']['breaches']]==['PYTHON.CLASS.DUPLICATE_METHOD','PYTHON.IMPORT.WILDCARD','PYTHON.EXCEPT.BARE']
assert p['result']['breach_count']==3 and p['result']['blockers']==1 and p['result']['advisories']==2
assert all(x['caused_by'] and x['fix']['correct'] and x['details'] and len(x['actions'])>=3 for x in p['result']['breaches'])
assert r['operation_status']['class']=='BREACHED'
assert set(x['rule'] for x in r['result']['breaches'])=={'OOREXX.DIRECTIVE.DUPLICATE_CLASS','OOREXX.DIRECTIVE.DUPLICATE_METHOD','OOREXX.REQUIRES.DUPLICATE'}
assert r['result']['breach_count']==3 and r['result']['blockers']==2 and r['result']['advisories']==1
PY
cycle=$("$PYTHON" -c 'import json,sys; print(json.load(open(sys.argv[1]))["result"]["cycle"])' "$TMP/py.json")
"$G" --profile oorexx rules show PYTHON.CLASS.DUPLICATE_METHOD --language python --return-to "$cycle" > "$TMP/page.json"
"$PYTHON" - "$TMP/page.json" "$cycle" <<'PY'
import json,sys
x=json.load(open(sys.argv[1])); c=sys.argv[2]
assert x['operation_status']['class']=='OPENED'
assert x['result']['page_type']=='LanguageRulePage'
assert x['result']['return_to']==c
assert x['result']['selectors'][0]['action']=='RETURN'
PY
# Invalid args are validation, not NOT_FOUND.
"$G" --profile oorexx exec source.language.rules.evaluate language=python > "$TMP/bad.json" || true
"$PYTHON" - "$TMP/bad.json" <<'PY'
import json,sys
x=json.load(open(sys.argv[1])); assert x['operation_status']['class']=='INVALID_ARGUMENT'; assert 'path' in x['result']['missing']
PY
# Rule docs participate in semantic merge and conflicting identities fail closed.
mkdir "$TMP/conflict"
cat > "$TMP/conflict/x.json" <<'JSON'
{"kind":"language-rule","id":"PYTHON.EXCEPT.BARE","version":"evil","language":"python","title":"collision"}
JSON
if "$G" merge "$ROOT/packs/core" "$TMP/conflict" > "$TMP/conflict.json"; then echo 'expected merge conflict' >&2; exit 1; fi
"$PYTHON" - "$TMP/conflict.json" <<'PY'
import json,sys
x=json.load(open(sys.argv[1])); assert x['operation_status']['class']=='CONFLICT'; assert x['result']['key']==['language-rule','PYTHON.EXCEPT.BARE']
PY
printf '%s\n' 'PASS ALL LLM GOPHER v0.7 LANGUAGE-RULE CYCLE TESTS'
