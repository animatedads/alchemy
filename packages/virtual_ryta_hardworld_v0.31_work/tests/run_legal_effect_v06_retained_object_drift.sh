#!/usr/bin/env bash
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"; ROOT="$(cd "$HERE/.." && pwd)"; LEGAL_ROOT="${LEGAL_EFFECT_ROOT:?set LEGAL_EFFECT_ROOT}"
TMP="$(mktemp "$HERE/.legal_v06_drift.XXXXXX.rex")"; trap 'rm -f "$TMP"' EXIT
python3 - "$HERE/test_legal_effect_v06_retained_object_drift.rex.in" "$TMP" "$ROOT" <<'PY'
from pathlib import Path
import sys
Path(sys.argv[2]).write_text(Path(sys.argv[1]).read_text().replace('__RYTA_ROOT__',sys.argv[3].replace("'","''")))
PY
cd "$HERE"; PATH="$LEGAL_ROOT/src:$PATH" rexx "$TMP"
