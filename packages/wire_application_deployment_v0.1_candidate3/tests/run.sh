#!/bin/sh
set -eu
: "$REXX" "$BASELINE_ROOT"
here="$(cd "$(dirname "$0")/.." && pwd)"
export REXX_PATH="$here/src:$BASELINE_ROOT/oorexx_queue_fabric_v0.9-dev6/src:$BASELINE_ROOT/alchemy_objects_v0.8/src:$BASELINE_ROOT/oorexx_crypto_v0.8.3/src"
for t in test_admission_replay.rex test_permanent_queue_restart.rex; do
 root="$(mktemp -d)"
 "$REXX" "$here/tests/$t" "$root"
 rm -rf "$root"
done
echo "PASS candidate3 GitHub regression"
