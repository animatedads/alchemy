#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TD="$(mktemp -d)"; trap 'rm -rf "$TD"' EXIT
mkdir -p "$TD/bin"
PY3="$(command -v python3)"
DIRNAME="$(command -v dirname)"
ln -s "$PY3" "$TD/bin/python3"
ln -s "$DIRNAME" "$TD/bin/dirname"
# Resolver must choose python3 when there is no `python` command.
resolved=$(PATH="$TD/bin" /bin/sh -c '. "$1/tests/python_env.sh"; printf "%s" "$PYTHON"' sh "$ROOT")
[ "$resolved" = "$TD/bin/python3" ] || { echo "wrong resolver result: $resolved" >&2; exit 1; }
# Launcher must also run with only python3 (+ dirname needed by the shell wrapper) visible.
PATH="$TD/bin" "$ROOT/gopher" --profile oorexx context oorexx > "$TD/context.json"
"$PY3" - "$TD/context.json" <<'PY'
import json,sys
x=json.load(open(sys.argv[1]))
assert x['tool_status']['class']=='OK'
assert x['operation_status']['class']=='OPENED'
PY
# Explicit override must win.
LLM_GOPHER_PYTHON="$PY3" "$ROOT/gopher" --profile oorexx context oorexx > "$TD/override.json"
"$PY3" - "$TD/override.json" <<'PY'
import json,sys
x=json.load(open(sys.argv[1])); assert x['operation_status']['class']=='OPENED'
PY
printf '%s\n' 'PASS LLM GOPHER v0.8-dev2 PYTHON PORTABILITY TESTS'
