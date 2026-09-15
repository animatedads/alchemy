#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
grep -q 'NON-AUTHORITATIVE FRONT-END FIXTURE' "$ROOT/web/preview.html"
grep -q 'AJI-STAT' "$ROOT/web/preview.html"
grep -q 'JPY' "$ROOT/web/preview.html"
grep -q 'AJI.PRODUCT.RATING.COMPOSITE/1' "$ROOT/web/preview.html"
grep -q 'AJI.BILLING.ALLOCATE.OLDEST_DUE/1' "$ROOT/web/preview.html"
grep -q 'No calculator lives in this page' "$ROOT/web/preview.html"
if grep -Eiq 'fetch\(|WebSocket\(|XMLHttpRequest|localStorage\.|eval\(|new Function' "$ROOT/web/preview.html" "$ROOT/web/preview.css"; then echo 'FAIL: preview contains live transport/state logic' >&2; exit 1; fi
# Currency must be explicit in early AJI operator UI.
grep -q '¥' "$ROOT/web/preview.html"
echo 'AJI PREVIEW BOUNDARY: OK'
