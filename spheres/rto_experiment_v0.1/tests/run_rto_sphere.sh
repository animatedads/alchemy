#!/bin/sh
set -eu
ROOT=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
G=${LLM_GOPHER:-gopher}
CORE=${LLM_GOPHER_CORE:?set LLM_GOPHER_CORE to the Gopher v0.19 core pack}
"$G" --pack "$CORE" --pack "$ROOT/packs/rto" context rto --full > "$ROOT/tests/context.json"
"$G" --pack "$CORE" --pack "$ROOT/packs/rto" open rto.start-here > "$ROOT/tests/start.json"
"$G" --pack "$CORE" --pack "$ROOT/packs/rto" lookup kind='strategy-ledger' --sphere rto > "$ROOT/tests/lookup.json"
python3 - "$ROOT/tests/context.json" "$ROOT/tests/start.json" "$ROOT/tests/lookup.json" <<'PY'
import json,sys
c,s,l=[json.load(open(x)) for x in sys.argv[1:]]
assert c['operation_status']['class']=='OPENED'
ids={x['id'] for x in c['result']['articles']}
assert {'rto.start-here','rto.architecture','rto.security','rto.known-issues'} <= ids
assert s['operation_status']['class']=='OPENED'
assert l['operation_status']['class']=='FOUND'
PY
rm -f "$ROOT/tests/context.json" "$ROOT/tests/start.json" "$ROOT/tests/lookup.json"
echo 'PASS RTO SPHERE TEST'
