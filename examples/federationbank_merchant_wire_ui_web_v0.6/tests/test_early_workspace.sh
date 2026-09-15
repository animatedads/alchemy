#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
for view in overview positions remediation settlement accounting market; do
  grep -q "data-preview-tab=\"$view\"" "$ROOT/web/preview.html"
  grep -q "data-preview-view=\"$view\"" "$ROOT/web/preview.html"
done
grep -q "activate('overview')" "$ROOT/web/preview.js"
grep -q 'Client state, contract truth, risk truth, settlement truth and accounting truth' "$ROOT/web/preview.html"
grep -q 'Actual exposure −200' "$ROOT/web/preview.html"
grep -q 'PARTIAL · £734.69' "$ROOT/web/preview.html"
grep -q '0 new journals' "$ROOT/web/preview.html"
grep -q 'Never infer successful execution from an approved plan' "$ROOT/docs/PROJECTION_REQUIREMENTS.md"
grep -q 'Never display an instruction as observed cash' "$ROOT/docs/PROJECTION_REQUIREMENTS.md"
grep -q 'Never infer accounting completion from cash settlement' "$ROOT/docs/PROJECTION_REQUIREMENTS.md"
echo 'FEDERATIONBANK MERCHANT EARLY WORKSPACE: OK'
