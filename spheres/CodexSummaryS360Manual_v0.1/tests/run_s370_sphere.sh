#!/bin/sh
set -eu
ROOT=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
G=${LLM_GOPHER:-gopher}
CORE=${LLM_GOPHER_CORE:?set LLM_GOPHER_CORE to the Gopher v0.19 core pack}
"$G" --pack "$CORE" --pack "$ROOT/packs/CodexSummaryS360Manual" context CodexSummaryS360Manual > "$ROOT/tests/context.json"
"$G" --pack "$CORE" --pack "$ROOT/packs/CodexSummaryS360Manual" open s360.storage > "$ROOT/tests/storage.json"
"$G" --pack "$CORE" --pack "$ROOT/packs/CodexSummaryS360Manual" lookup path='/home/hc3/Downloads/GA22-7000-6_IBM_System_370_Principles_of_Operation_7th_ed_198003.pdf' --sphere CodexSummaryS360Manual > "$ROOT/tests/manual.json"
python3 - "$ROOT/tests/context.json" "$ROOT/tests/storage.json" "$ROOT/tests/manual.json" <<'PY'
import json,sys
c,s,m=[json.load(open(x)) for x in sys.argv[1:]]
assert c['operation_status']['class']=='OPENED'
assert s['operation_status']['class']=='OPENED'
assert s['result']['printed_pages']=='3-1 through 3-24'
assert m['operation_status']['class']=='FOUND'
PY
rm -f "$ROOT/tests/context.json" "$ROOT/tests/storage.json" "$ROOT/tests/manual.json"
echo 'PASS S370 SPHERE TEST'
