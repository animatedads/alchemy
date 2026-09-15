#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
grep -q 'NON-AUTHORITATIVE FRONT-END FIXTURE' "$ROOT/web/preview.html"
grep -q 'Access Control admitted' "$ROOT/web/preview.html"
grep -q 'Exact method permission' "$ROOT/web/preview.html"
grep -q 'Staff Authority' "$ROOT/web/preview.html"
grep -q 'Core Banking' "$ROOT/web/preview.html"
grep -q 'enabled UI control grants none' "$ROOT/web/preview.html"
if grep -Eiq 'fetch\(|WebSocket\(|XMLHttpRequest|localStorage\.' "$ROOT/web/preview.html" "$ROOT/web/preview.css"; then
  echo 'FAIL: preview fixture contains live transport/state logic' >&2; exit 1
fi
echo 'FEDERATIONBANK STAFF PREVIEW BOUNDARY: OK'
