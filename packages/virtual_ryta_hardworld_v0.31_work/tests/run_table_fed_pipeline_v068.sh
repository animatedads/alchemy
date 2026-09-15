#!/usr/bin/env bash
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
NOSQL_CLS="${1:-}"
if [[ -z "$NOSQL_CLS" || ! -f "$NOSQL_CLS" ]]; then
  echo "usage: $0 /path/to/nosqlserver_v0.68/src/NoSQLServer.cls" >&2
  exit 2
fi
NOSQL_CLS="$(realpath "$NOSQL_CLS")"
TMP_REX="$(mktemp "$HERE/.table_feed_v068.XXXXXX.rex")"
ROOT="$(mktemp -d /tmp/virtual_ryta_table_feed_v08.XXXXXX)"
cleanup(){ rm -f "$TMP_REX"; rm -rf "$ROOT"; }
trap cleanup EXIT
python3 - "$HERE/test_table_fed_algorithm_pipeline_v068.rex.in" "$TMP_REX" "$NOSQL_CLS" <<'PY'
from pathlib import Path
import sys
src=Path(sys.argv[1]).read_text()
path=sys.argv[3].replace("'", "''")
Path(sys.argv[2]).write_text(src.replace('__NOSQLSERVER_CLS__', path))
PY
cd "$HERE"
rexx "$TMP_REX" "$ROOT"
