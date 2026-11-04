#!/usr/bin/env bash
set -euo pipefail
ROOT=$(cd "$(dirname "$0")/.." && pwd)
X="$ROOT/tools/x3270_tso_read_discovery.sh"
N="$ROOT/tools/s3270_reference_discovery.rex"
D="$ROOT/tools/run_dual_terminal_machine_tso_live.sh"

grep -q 'X3270_READBUFFER_RESPONSE' "$X"
grep -q "ReadBuffer(Ascii)" "$X"
grep -q 'S3270ReferenceParser~parseActionResponse' "$N"
grep -q 'CHARACTER_ATTRIBUTES","DIGEST' "$N"
grep -q 'NONDISPLAY' "$N"
! grep -q 'rowText' "$N"
grep -q 's3270-readbuffer.txt' "$D"
grep -q 'candidate16 detached s3270 semantic evidence retained' "$D"
echo "PASS candidate16 detached s3270 evidence contract"
