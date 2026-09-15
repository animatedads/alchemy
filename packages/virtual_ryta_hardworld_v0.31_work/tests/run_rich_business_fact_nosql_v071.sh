#!/usr/bin/env bash
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
NOSQL_CLS="${1:-}"
if [[ -z "$NOSQL_CLS" || ! -f "$NOSQL_CLS" ]]; then
  echo "usage: $0 /path/to/nosqlserver_v0.71/src/NoSQLServer.cls" >&2
  exit 2
fi
NOSQL_CLS="$(realpath "$NOSQL_CLS")"
TMP_REX="$(mktemp "$HERE/.rich_fact_v071.XXXXXX.rex")"
ROOT="$(mktemp -d /tmp/virtual_ryta_rich_v071.XXXXXX)"
cleanup(){ rm -f "$TMP_REX"; rm -rf "$ROOT"; }
trap cleanup EXIT
python3 - "$HERE/test_rich_business_fact_nosql_v071.rex.in" "$TMP_REX" "$NOSQL_CLS" <<'PY'
from pathlib import Path
import sys
src=Path(sys.argv[1]).read_text()
Path(sys.argv[2]).write_text(src.replace('__NOSQLSERVER_CLS__', sys.argv[3].replace("'", "''")))
PY
cd "$HERE"
rexx "$TMP_REX" "$ROOT"
