#!/usr/bin/env bash
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
NOSQL_CLS="${1:-}"
LEGAL_ROOT="${LEGAL_EFFECT_ROOT:?set LEGAL_EFFECT_ROOT}"
if [[ -z "$NOSQL_CLS" || ! -f "$NOSQL_CLS" ]]; then
  echo "usage: $0 /path/to/nosqlserver_v0.71/src/NoSQLServer.cls" >&2
  exit 2
fi
NOSQL_CLS="$(realpath "$NOSQL_CLS")"
TMP_REX="$(mktemp "$HERE/.legal_promo_v071.XXXXXX.rex")"
ROOT="$(mktemp -d /tmp/legal_promotion_v071.XXXXXX)"
cleanup(){ rm -f "$TMP_REX"; rm -rf "$ROOT"; }
trap cleanup EXIT
python3 - "$HERE/test_legal_promotion_nosql_v071.rex.in" "$TMP_REX" "$NOSQL_CLS" <<'PY'
from pathlib import Path
import sys
src=Path(sys.argv[1]).read_text()
Path(sys.argv[2]).write_text(src.replace('__NOSQLSERVER_CLS__',sys.argv[3].replace("'","''")))
PY
cd "$HERE"
PATH="$LEGAL_ROOT/src:$PATH" rexx "$TMP_REX" "$ROOT"
