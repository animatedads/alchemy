#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
grep -q 'NON-AUTHORITATIVE PREVIEW' "$ROOT/web/preview.html"
grep -q 'UNKNOWN_PENDING_RECONCILIATION' "$ROOT/web/preview.html"
grep -q 'Execution sees VMM contract references only' "$ROOT/web/preview.html"
grep -q 'Federation is lender evidence, not VMM book authority' "$ROOT/web/preview.html"
grep -q 'ISIN + venue/listing + quote/settlement currency' "$ROOT/web/preview.html"
if grep -Eiq 'fetch\(|WebSocket\(|XMLHttpRequest|localStorage\.setItem|QueueFabricGatewayTransport' "$ROOT/web/preview.html" "$ROOT/web/preview.css"; then
  echo 'FAIL: preview fixture contains live transport/state logic' >&2
  exit 1
fi
echo 'VMM PREVIEW BOUNDARY: OK'
