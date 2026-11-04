#!/usr/bin/env bash
set -euo pipefail
ROOT=$(cd "$(dirname "$0")/.." && pwd)
for f in \
  "$ROOT/tools/x3270_tso_read_discovery.sh" \
  "$ROOT/tools/run_dual_mvs_x3270_tso_live.sh" \
  "$ROOT/tools/run_x3270_tso_intention_live.sh"
do
  ! grep -q 'PASS4U' "$f"
done
grep -q 'TSO_PASSWORD is required at runtime' "$ROOT/tools/x3270_tso_read_discovery.sh"
echo "PASS authenticated reference tooling has no packaged TSO password"
