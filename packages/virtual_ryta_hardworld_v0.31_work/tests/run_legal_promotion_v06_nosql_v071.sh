#!/usr/bin/env bash
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"; NOSQL_CLS="${1:-}"; LEGAL_ROOT="${LEGAL_EFFECT_ROOT:?set LEGAL_EFFECT_ROOT}"
[[ -n "$NOSQL_CLS" && -f "$NOSQL_CLS" ]] || { echo "usage: $0 /path/to/NoSQLServer.cls" >&2; exit 2; }
NOSQL_CLS="$(realpath "$NOSQL_CLS")"; TMP="$(mktemp "$HERE/.legal_promo_v06_v071.XXXXXX.rex")"; ROOT="$(mktemp -d /tmp/legal_promo_v06_v071.XXXXXX)"
trap 'rm -f "$TMP"; rm -rf "$ROOT"' EXIT
python3 - "$HERE/test_legal_promotion_v06_nosql_v071.rex.in" "$TMP" "$NOSQL_CLS" <<'PY'
from pathlib import Path
import sys
Path(sys.argv[2]).write_text(Path(sys.argv[1]).read_text().replace('__NOSQLSERVER_CLS__',sys.argv[3].replace("'","''")))
PY
cd "$HERE"; PATH="$LEGAL_ROOT/src:$PATH" rexx "$TMP" "$ROOT"
