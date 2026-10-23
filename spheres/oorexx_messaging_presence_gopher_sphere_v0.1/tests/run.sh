#!/usr/bin/env bash
set -euo pipefail
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
python3 - <<'PY' "$ROOT"
import json, pathlib, sys
root=pathlib.Path(sys.argv[1])
for p in root.rglob('*.json'):
    json.loads(p.read_text())
print('PASS messaging-presence sphere JSON')
PY
