#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
NOSQL_CLS="${1:-}"
if [[ -z "$NOSQL_CLS" ]]; then
  echo "usage: $0 /path/to/NoSQLServer.cls" >&2
  exit 2
fi
NOSQL_CLS="$(readlink -f "$NOSQL_CLS")"
TMP="$(mktemp ./test_librarian_nosql_v068_external_engine.XXXXXX.rex)"
ROOT="$(mktemp -d /tmp/librarian_nosql_v09.XXXXXX)"
trap 'rm -f "$TMP"; rm -rf "$ROOT"' EXIT
python3 - "$NOSQL_CLS" "$TMP" <<'PY'
from pathlib import Path
import sys
src=Path('test_librarian_nosql_v068_external_engine.rex.in').read_text()
Path(sys.argv[2]).write_text(src.replace('__NOSQLSERVER_CLS__', sys.argv[1]))
PY
rexx "$TMP" "$ROOT"
