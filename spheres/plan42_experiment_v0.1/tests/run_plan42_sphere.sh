#!/bin/sh
set -eu
ROOT=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
G=${LLM_GOPHER:-gopher}
CORE=${LLM_GOPHER_CORE:?set LLM_GOPHER_CORE to the Gopher v0.19 core pack}
"$G" --pack "$CORE" --pack "$ROOT/packs/plan42" context plan42 --full > "$ROOT/tests/context.json"
"$G" --pack "$CORE" --pack "$ROOT/packs/plan42" open plan42.start-here > "$ROOT/tests/start.json"
"$G" --pack "$CORE" --pack "$ROOT/packs/plan42" lookup path='docs/KNOWN_ISSUES.md' --sphere plan42 > "$ROOT/tests/lookup.json"
python3 - "$ROOT/tests/context.json" "$ROOT/tests/start.json" "$ROOT/tests/lookup.json" <<'PY'
import json,sys
c,s,l=[json.load(open(x)) for x in sys.argv[1:]]
assert c['operation_status']['class']=='OPENED'
ids={x['id'] for x in c['result']['articles']}
assert {'plan42.start-here','plan42.architecture','plan42.known-issues','plan42.standalone-boundary'} <= ids
assert s['operation_status']['class']=='OPENED'
assert l['operation_status']['class']=='FOUND'
PY
rm -f "$ROOT/tests/context.json" "$ROOT/tests/start.json" "$ROOT/tests/lookup.json"
echo 'PASS PLAN42 SPHERE TEST'
