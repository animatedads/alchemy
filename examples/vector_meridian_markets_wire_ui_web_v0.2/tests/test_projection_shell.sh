#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
node --check "$ROOT/web/bootstrap-config.js"
node --check "$ROOT/web/vmm-wire-ui.js"
node --test "$ROOT/tests/test_bootstrap_config.mjs"
# Live browser shell must not contain hard-coded VMM trading/business commands or engine references.
if grep -Eiq 'CREATE_ORDER|ROUTE_ORDER|EXECUTE_ORDER|EXECUTION_FILL|CANCEL_ORDER|KILL_ALGO|RESUME_ALGO|SETTLE_|CLOSEOUT_|POST_JOURNAL|VMMMarketMaker|VMMExecutionService|VMMInstitutionalSyntheticService|VMMAccountingService|accountId|debitThisAccount' "$ROOT/web/index.html" "$ROOT/web/vmm-wire-ui.js"; then
  echo 'FAIL: live VMM browser shell contains hard-coded domain semantics' >&2
  exit 1
fi
grep -q 'wire-ui-root' "$ROOT/web/index.html"
grep -q 'QueueFabricGatewayTransport' "$ROOT/web/vmm-wire-ui.js"
grep -q 'MaterialController' "$ROOT/web/vmm-wire-ui.js"
grep -q 'bootstrapUrl' "$ROOT/web/index.html"
grep -q "putResultMode: 'required'" "$ROOT/web/vmm-wire-ui.js"
grep -q 'Independent principal market maker' "$ROOT/web/index.html"
grep -q "siteId: config.siteId ?? 'VECTOR_MERIDIAN_MARKETS'" "$ROOT/web/vmm-wire-ui.js"
echo 'VMM WIRE UI PROJECTION SHELL: OK'
