#!/bin/sh
set -eu
ROOT=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd); G=${LLM_GOPHER:-gopher}; CORE=${LLM_GOPHER_CORE:?set LLM_GOPHER_CORE}
"$G" --pack "$CORE" --pack "$ROOT/packs/python-manual" context python-manual > "$ROOT/tests/context.json"
"$G" --pack "$CORE" --pack "$ROOT/packs/python-manual" open python.question-routing > "$ROOT/tests/article.json"
"$G" --pack "$CORE" --pack "$ROOT/packs/python-manual" lookup artifact='https://docs.python.org/3.13/reference/' --sphere python-manual > "$ROOT/tests/source.json"
python3 - "$ROOT/tests/context.json" "$ROOT/tests/article.json" "$ROOT/tests/source.json" <<'PY'
import json,sys
c,a,s=[json.load(open(x)) for x in sys.argv[1:]]
assert c['operation_status']['class']=='OPENED'; assert a['operation_status']['class']=='OPENED'; assert s['operation_status']['class']=='FOUND'
PY
rm -f "$ROOT/tests/context.json" "$ROOT/tests/article.json" "$ROOT/tests/source.json"; echo 'PASS PYTHON MANUAL SPHERE TEST'
