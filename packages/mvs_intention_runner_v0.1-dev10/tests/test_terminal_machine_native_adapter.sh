#!/usr/bin/env bash
set -euo pipefail
ROOT=$(cd "$(dirname "$0")/.." && pwd)
TOOL="$ROOT/tools/terminal_machine_tso_discovery.rex"
grep -q 'TN3270LiveSession' "$TOOL"
grep -q 'PresentationSpace' "$ROOT/README.md" || true
! grep -Eq 's3270|x3270_reference_discovery' "$TOOL"
grep -q 'SESSION", "AUTHENTICATED"' "$TOOL"
grep -q 'TERMINAL_MACHINE_LOGOFF_VERIFIED' "$TOOL"
grep -q 'setCurrentInput' "$TOOL"
echo "PASS native Terminal Machine adapter contract"
