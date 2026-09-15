#!/usr/bin/env bash
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"; ROOT="$(cd "$HERE/.." && pwd)"
PLUGIN_ROOT="${STRUCTURED_RELATION_ROOT:?set STRUCTURED_RELATION_ROOT}"; LEGAL_ROOT="${LEGAL_EFFECT_ROOT:?set LEGAL_EFFECT_ROOT}"; FIXTURES="$PLUGIN_ROOT/tests/fixtures"
TMP="$(mktemp "$HERE/.structured_legal_v019_v06.XXXXXX.rex")"; trap 'rm -f "$TMP"' EXIT
python3 - "$HERE/test_structured_legal_promotion_v019_v06.rex.in" "$TMP" "$PLUGIN_ROOT" "$FIXTURES" "$ROOT" <<'PY'
from pathlib import Path
import sys
s=Path(sys.argv[1]).read_text()
for k,v in {'__PLUGIN_ROOT__':sys.argv[3],'__PLUGIN_FIXTURES__':sys.argv[4],'__RYTA_ROOT__':sys.argv[5]}.items():
    s=s.replace(k,v.replace("'","''"))
Path(sys.argv[2]).write_text(s)
PY
cd "$HERE"; PATH="$LEGAL_ROOT/src:$PATH" rexx "$TMP"
