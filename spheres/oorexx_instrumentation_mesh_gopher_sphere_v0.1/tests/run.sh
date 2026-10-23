#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
python3 - "$ROOT" <<'PY'
import json, pathlib, sys
root=pathlib.Path(sys.argv[1])
for p in sorted(root.rglob("*.json")):
    json.loads(p.read_text())
sphere=json.loads((root/"packs/instrumentation-mesh/00-sphere.json").read_text())
assert sphere["id"]=="instrumentation-mesh"
authority=json.loads((root/"packs/instrumentation-mesh/articles/instrumentation-mesh.authority.json").read_text())
assert authority["verified_baseline"]["sha256"]=="47402459e658da6ddb17c65c98010c0acd0e35d43b3a0b01c8c13c835f65d624"
noc=json.loads((root/"packs/instrumentation-mesh/articles/instrumentation-mesh.keynote-noc.json").read_text())
assert noc["verified_consumer"]["sha256"]=="dd34cdca59399b6bc95aef87adf69eb7f21b97793016298be45cc152ccfcb821"
missing=(root/"MISSING_WORK.md").read_text()
for phrase in ("dev29.25 collector-join","live multi-node QueueRexx/XTP","Alchemy Log"):
    assert phrase in missing
print("PASS instrumentation-mesh sphere JSON/provenance/continuation guards")
PY
