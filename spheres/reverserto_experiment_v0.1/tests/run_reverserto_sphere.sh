#!/bin/sh
set -eu
ROOT=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
G=${LLM_GOPHER:-gopher}
CORE=${LLM_GOPHER_CORE:?set LLM_GOPHER_CORE to the Gopher v0.19 core pack}
"$G" --pack "$CORE" --pack "$ROOT/packs/reverserto" context reverserto --full > "$ROOT/tests/context.json"
"$G" --pack "$CORE" --pack "$ROOT/packs/reverserto" open reverserto.start-here > "$ROOT/tests/start.json"
"$G" --pack "$CORE" --pack "$ROOT/packs/reverserto" lookup kind='strategy-ledger' --sphere reverserto > "$ROOT/tests/lookup.json"
python3 - "$ROOT/tests/context.json" "$ROOT/tests/start.json" "$ROOT/tests/lookup.json" <<'PY'
import json,sys
c,s,l=[json.load(open(x)) for x in sys.argv[1:]]
assert c['operation_status']['class']=='OPENED'
ids={x['id'] for x in c['result']['articles']}
assert {'reverserto.start-here','reverserto.architecture','reverserto.security','reverserto.known-issues'} <= ids
assert s['operation_status']['class']=='OPENED'
assert l['operation_status']['class']=='FOUND'
PY
rm -f "$ROOT/tests/context.json" "$ROOT/tests/start.json" "$ROOT/tests/lookup.json"
echo 'PASS REVERSERTO SPHERE TEST'
