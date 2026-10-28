#!/bin/sh
set -eu
cd "$(dirname "$0")"
python3 -m unittest discover -s tests -v
python3 -m py_compile src/spectral_integrity.py src/blind_trial.py
python3 - <<'PY'
import json
from pathlib import Path
for p in Path('sphere').rglob('*.json'):
    json.loads(p.read_text())
print('PASS sphere JSON syntax')
PY
