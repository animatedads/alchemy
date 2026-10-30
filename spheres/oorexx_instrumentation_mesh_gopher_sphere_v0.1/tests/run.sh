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
qual=json.loads((root/"packs/instrumentation-mesh/articles/qual.instrumentation-mesh.current.json").read_text())
assert qual["source_publication"]["sha256"]=="47402459e658da6ddb17c65c98010c0acd0e35d43b3a0b01c8c13c835f65d624"
assert qual["source_publication"]["package_path"]=="packages/oorexx_instrumentation_mesh"
assert qual["qualification"]["fresh_requalification_2026_10_29"] is False
compat=qual["current_producer_compatibility_2026_10_29"]
assert compat["result"]=="PASS static/source compatibility"
assert "0.4.8" in compat["https_server"]
assert "0.1-dev22" in compat["ldap_identity"]
assert "0.1-dev16" in compat["rexxos_rto2_grid"]
report=root/"qualification/CURRENT_PRODUCER_COMPATIBILITY_2026-10-29.md"
checker=root/"qualification/check_current_producers.py"
assert report.is_file()
assert checker.is_file()
missing=(root/"MISSING_WORK.md").read_text()
for phrase in ("dev29.25 collector-join","live multi-node QueueRexx/XTP","Alchemy Log","Completed source-publication gate","Current producer compatibility closed statically"):
    assert phrase in missing
assert "exact runtime source, tests, package metadata" in missing
print("PASS instrumentation-mesh sphere JSON/provenance/source-publication/current-producer/continuation guards")
PY
