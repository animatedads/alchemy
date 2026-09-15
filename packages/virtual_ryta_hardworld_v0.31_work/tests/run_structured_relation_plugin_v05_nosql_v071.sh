#!/usr/bin/env bash
set -euo pipefail
PLUGIN_ROOT=${1:?usage: $0 /path/to/structured_relation_plugin_v0.5 /path/to/NoSQLServer.cls}
NOSQL_CLS=${2:?usage: $0 /path/to/structured_relation_plugin_v0.5 /path/to/NoSQLServer.cls}
SELF_DIR=$(cd "$(dirname "$0")" && pwd)
RYTA_ROOT=$(cd "$SELF_DIR/.." && pwd)
PLUGIN_ROOT=$(realpath "$PLUGIN_ROOT")
NOSQL_CLS=$(realpath "$NOSQL_CLS")
TMP=$(mktemp "$SELF_DIR/.structured-v05-nosql.XXXXXX.rex")
DBROOT=$(mktemp -d /tmp/structured-v05-nosql.XXXXXX)
cleanup(){ rm -f "$TMP"; rm -rf "$DBROOT"; }
trap cleanup EXIT
python3 - "$SELF_DIR/test_structured_relation_plugin_v05_nosql_v071.rex.in" "$TMP" "$PLUGIN_ROOT" "$NOSQL_CLS" "$RYTA_ROOT" <<'PY'
from pathlib import Path
import sys
src=Path(sys.argv[1]).read_text()
src=src.replace('__PLUGIN_ROOT__',str(Path(sys.argv[3]).resolve()))
src=src.replace('__PLUGIN_FIXTURES__',str((Path(sys.argv[3]).resolve()/'tests'/'fixtures')))
src=src.replace('__NOSQLSERVER_CLS__',str(Path(sys.argv[4]).resolve()))
src=src.replace('__RYTA_ROOT__',str(Path(sys.argv[5]).resolve()))
Path(sys.argv[2]).write_text(src)
PY
(cd "$SELF_DIR" && rexx "$(basename "$TMP")" "$DBROOT")
