#!/usr/bin/env bash
set -euo pipefail
PLUGIN_ROOT=${1:?usage: $0 /path/to/structured_relation_plugin_v0.5}
SELF_DIR=$(cd "$(dirname "$0")" && pwd)
RYTA_ROOT=$(cd "$SELF_DIR/.." && pwd)
TMP=$(mktemp "$SELF_DIR/structured-ryta-bridge.XXXXXX.rex")
trap 'rm -f "$TMP"' EXIT
python3 - "$SELF_DIR/test_structured_relation_plugin_v05_bridge.rex.in" "$TMP" "$PLUGIN_ROOT" "$RYTA_ROOT" <<'PY'
from pathlib import Path
import sys
src=Path(sys.argv[1]).read_text()
src=src.replace('__PLUGIN_ROOT__', str(Path(sys.argv[3]).resolve()))
src=src.replace('__PLUGIN_FIXTURES__', str((Path(sys.argv[3]).resolve()/'tests'/'fixtures')))
src=src.replace('__RYTA_ROOT__', str(Path(sys.argv[4]).resolve()))
Path(sys.argv[2]).write_text(src)
PY
(cd "$SELF_DIR" && rexx "$(basename "$TMP")")
