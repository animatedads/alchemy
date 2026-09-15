#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
node --check "$ROOT/web/preview.js"
grep -q 'NON-AUTHORITATIVE FRONT-END FIXTURE' "$ROOT/web/preview.html"
grep -q 'Client CLOSED does not mean Merchant risk closed' "$ROOT/web/preview.html"
grep -q 'EXECUTION_DIVERGENCE' "$ROOT/web/preview.html"
grep -q 'WRONG_WAY_EXECUTION' "$ROOT/web/preview.html"
grep -q 'Obligations, instructions &amp; observations' "$ROOT/web/preview.html"
grep -q 'DERIVATIVE' "$ROOT/web/preview.html" || grep -q 'Derivative-settlement control' "$ROOT/web/preview.html"
grep -q 'MERCHANT_SETTLEMENT_AMOUNT_AUTHORITY_REQUIRED' "$ROOT/web/preview.html"
grep -q 'HEDGE_IMPAIRED' "$ROOT/web/preview.html"
if grep -Eiq 'fetch\(|WebSocket\(|XMLHttpRequest|navigator\.sendBeacon|localStorage\.setItem|sessionStorage\.setItem' "$ROOT/web/preview.html" "$ROOT/web/preview.css" "$ROOT/web/preview.js"; then
  echo 'FAIL: preview fixture contains live transport/persistent-state logic' >&2
  exit 1
fi
# Preview buttons may only drive local view selection; no form/submission surface is allowed.
if grep -Eiq '<form|type="submit"|contenteditable|method=' "$ROOT/web/preview.html"; then
  echo 'FAIL: early preview contains an apparent mutation/submission surface' >&2
  exit 1
fi
echo 'FEDERATIONBANK MERCHANT EARLY UI PREVIEW BOUNDARY: OK'
