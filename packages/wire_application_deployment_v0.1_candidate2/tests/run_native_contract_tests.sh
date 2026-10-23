#!/usr/bin/env bash
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
: "$BASELINE_ROOT" "$REXX" "$REXXC"
# Apply HTTPS_SERVER.patch and WIRE_UI_SERVER.patch to fresh source first.
# The script intentionally never mutates baselines.
export REXX_PATH="$(dirname "$REXX"):$HERE/src:$BASELINE_ROOT/oorexx_https_server_v0.5/rexx:$BASELINE_ROOT/wire_ui_server_v0.17.1/src:$BASELINE_ROOT/oorexx_queue_fabric_web_gateway_v0.2/src:$BASELINE_ROOT/oorexx_deployment_v0.1-dev3/src:$BASELINE_ROOT/alchemy_objects_v0.8/src:$BASELINE_ROOT/oorexx_queue_fabric_v0.9-dev6/src:$BASELINE_ROOT/oorexx_crypto_v0.8.3/src"
for test in test_hosted_routes test_hosted_application_deploy test_wire_deploy_slots test_wire_hosted_coordinator test_wire_deploy_ingress; do
  echo "=== $test ==="
  "$REXX" "$HERE/tests/$test.rex"
done
for file in "$HERE"/src/*.cls "$BASELINE_ROOT/oorexx_https_server_v0.5/rexx/https_server.cls" "$BASELINE_ROOT/wire_ui_server_v0.17.1/src/WireUIServer.cls"; do
  "$REXXC" "$file" "/tmp/$(basename "$file").rxs"
done
echo "PASS candidate2 native contracts"
