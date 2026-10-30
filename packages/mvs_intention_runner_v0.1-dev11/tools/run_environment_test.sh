#!/usr/bin/env bash
set -euo pipefail
HERE=$(cd "$(dirname "$0")/.." && pwd)
OOREXX_DEB=${OOREXX_DEB:-/mnt/data/oorexx-5.3.0-13196.ubuntu1604debug.x86_64\(20261006-092552\).deb}
WORK=${TMPDIR:-/tmp}/mvs-intention-dev9-oorexx
rm -rf "$WORK"
mkdir -p "$WORK"
dpkg-deb -x "$OOREXX_DEB" "$WORK"
REXX=$(find "$WORK" -type f -path '*/bin/rexx' | head -1)
if [[ -z "$REXX" ]]; then echo "FAIL: rexx not found in $OOREXX_DEB"; exit 1; fi
RHOME=$(dirname "$(dirname "$REXX")")
export LD_LIBRARY_PATH="$RHOME/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
export REXX_PATH="$HERE/src:$HERE/vendor/intention:$HERE/vendor/intention/nlp"
"$REXX" -v 2>&1 | head -3
for t in "$HERE"/tests/*.rex; do
  echo "== $(basename "$t") =="
  "$REXX" "$t"
done
printf 'what system am I on\nfind the last failed compile for Fred\n\n' | "$REXX" "$HERE/examples/mvs_intention.rex" ED209Z
"$HERE/tests/test_x3270_reference_adapter.sh"
"$HERE/tests/test_x3270_tso_read_adapter.sh"
"$HERE/tests/test_x3270_tso_negative_adapter.sh"
"$HERE/tests/test_x3270_tso_failure_transcript.sh"
"$HERE/tests/test_terminal_machine_native_adapter.sh"
"$HERE/tests/test_candidate16_s3270_evidence_contract.sh"
"$HERE/tests/test_no_packaged_tso_password.sh"
"$REXX" "$HERE/tests/test_mas_pre23_completion_gate.rex"
echo "PASS mvs_intention_runner_v0.1-dev11 environment qualification"
