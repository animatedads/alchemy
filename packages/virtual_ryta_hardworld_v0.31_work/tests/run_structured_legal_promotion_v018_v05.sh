#!/usr/bin/env bash
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"
PLUGIN_ROOT="${STRUCTURED_RELATION_ROOT:?set STRUCTURED_RELATION_ROOT}"
LEGAL_ROOT="${LEGAL_EFFECT_ROOT:?set LEGAL_EFFECT_ROOT}"
FIXTURES="$PLUGIN_ROOT/tests/fixtures"
TMP_REX="$(mktemp "$HERE/.structured_legal_v018_v05.XXXXXX.rex")"
cleanup(){ rm -f "$TMP_REX"; }
trap cleanup EXIT
python3 - "$HERE/test_structured_legal_promotion_v018_v05.rex.in" "$TMP_REX" "$PLUGIN_ROOT" "$FIXTURES" "$ROOT" <<'PY'
from pathlib import Path
import sys
src=Path(sys.argv[1]).read_text()
for key,val in {
    '__PLUGIN_ROOT__':sys.argv[3],
    '__PLUGIN_FIXTURES__':sys.argv[4],
    '__RYTA_ROOT__':sys.argv[5],
}.items():
    src=src.replace(key,val.replace("'","''"))
Path(sys.argv[2]).write_text(src)
PY
cd "$HERE"
PATH="$LEGAL_ROOT/src:$PATH" rexx "$TMP_REX"
