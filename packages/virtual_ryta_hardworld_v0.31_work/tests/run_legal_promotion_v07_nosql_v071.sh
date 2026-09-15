#!/usr/bin/env bash
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
NOSQL_CLS="${1:-}"
LEGAL_ROOT="${LEGAL_EFFECT_ROOT:?set LEGAL_EFFECT_ROOT}"
RUNTIME_ROOT="${RUNTIME_REGISTRY_ROOT:?set RUNTIME_REGISTRY_ROOT}"
[[ -n "$NOSQL_CLS" && -f "$NOSQL_CLS" ]] || { echo "usage: $0 /path/to/NoSQLServer.cls" >&2; exit 2; }
NOSQL_CLS="$(realpath "$NOSQL_CLS")"
TMP="$(mktemp "$HERE/.legal_promo_v07_v071.XXXXXX.rex")"
ROOT_TMP="$(mktemp -d /tmp/legal_promo_v07_v071.XXXXXX)"
trap 'rm -f "$TMP"; rm -rf "$ROOT_TMP"' EXIT
python3 - "$HERE/test_legal_promotion_v07_nosql_v071.rex.in" "$TMP" "$NOSQL_CLS" <<'PY'
from pathlib import Path
import sys
Path(sys.argv[2]).write_text(Path(sys.argv[1]).read_text().replace('__NOSQLSERVER_CLS__',sys.argv[3].replace("'","''")))
PY
export PATH="$LEGAL_ROOT/src:$RUNTIME_ROOT/src:$PATH"
export REXX_PATH="$LEGAL_ROOT/src:$RUNTIME_ROOT/src${REXX_PATH:+:$REXX_PATH}"
cd "$HERE"
rexx "$TMP" "$ROOT_TMP"
