#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
node --check "$ROOT/web/bootstrap-config.js"
node --check "$ROOT/web/flylo-wire-ui.js"
node --test "$ROOT/tests/test_bootstrap_config.mjs"
if grep -Eiq '<form|FLIGHT\.(SEARCH|SELECT)|ASSISTANT\.(OPEN|ASK)|BOOKING\.LOOKUP' "$ROOT/web/index.html" "$ROOT/web/flylo-wire-ui.js"; then
  echo 'FAIL: browser shell contains hard-coded business interaction semantics' >&2
  exit 1
fi
grep -q 'wire-ui-root' "$ROOT/web/index.html"
grep -q 'QueueFabricGatewayTransport' "$ROOT/web/flylo-wire-ui.js"
grep -q 'MaterialController' "$ROOT/web/flylo-wire-ui.js"
grep -q -- '--wui-brand-pink' "$ROOT/web/flylo-wire-ui.css"
grep -q 'bootstrapUrl' "$ROOT/web/index.html"
grep -q "putResultMode: 'required'" "$ROOT/web/flylo-wire-ui.js"
echo 'FLYLO WIRE UI PROJECTION SHELL: OK'
