#!/bin/sh
set -eu
base="$(cd "$(dirname "$0")" && pwd)"
export REXX_PATH="$(dirname "$REXX"):$base/src:$WAPP3_ROOT/overlays/general-deployment/src:$DEPLOY4_ROOT/src:$BASELINE_ROOT/oorexx_queue_fabric_v0.9-dev6/src:$BASELINE_ROOT/alchemy_objects_v0.8/src:$BASELINE_ROOT/oorexx_crypto_v0.8.3/src"
for f in test_live_evidence_gate.rex test_unprobed_replay.rex; do
 d="$(mktemp -d)"
 "$REXX" "$base/tests/$f" "$d"
 rm -rf "$d"
done
"$REXXC" "$base/src/WireDeploymentLiveEvidenceGate.cls" "/tmp/WireDeploymentLiveEvidenceGate.rxs"
echo 'PASS Candidate4 native evidence qualification'
