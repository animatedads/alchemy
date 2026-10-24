#!/usr/bin/env bash
set -euo pipefail
base="$(cd "$(dirname "$0")/.." && pwd)"
test -s "$base/README.md"
test -s "$base/packs/physics-world/articles/physics-world.continuity.json"
test -s "$base/profiles/physics-world.json"
test -s "$base/qualification/QUALIFICATION.txt"
python3 - "$base" <<'PY'
import json, pathlib, sys
b=pathlib.Path(sys.argv[1])
json.load(open(b/'packs/physics-world/articles/physics-world.continuity.json'))
json.load(open(b/'profiles/physics-world.json'))
print('PHYSICS WORLD SPHERE: OK')
PY
