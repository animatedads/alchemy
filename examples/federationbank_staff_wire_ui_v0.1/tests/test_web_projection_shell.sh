#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
node --check "$ROOT/web/bootstrap-config.js"
node --check "$ROOT/web/staff-wire-ui.js"
node --test "$ROOT/tests/test_bootstrap_config.mjs"
# The live browser shell must not hard-code banking operations or authority decisions.
if grep -Eiq 'CUSTOMER\.TRANSFER\.SUBMIT|FBSTAFFCH|OPEN_ACCOUNT|TRANSFER|StaffAuthorityEnvelope|PermissionAdmission|LEDGER|sourceAccountId|targetAccountId|amountMinor' "$ROOT/web/index.html" "$ROOT/web/staff-wire-ui.js"; then
  echo 'FAIL: live browser shell contains hard-coded Staff Banking domain semantics' >&2; exit 1
fi
grep -q 'wire-ui-root' "$ROOT/web/index.html"
grep -q 'QueueFabricGatewayTransport' "$ROOT/web/staff-wire-ui.js"
grep -q 'MaterialController' "$ROOT/web/staff-wire-ui.js"
grep -q "putResultMode: 'required'" "$ROOT/web/staff-wire-ui.js"
grep -q 'bootstrapUrl' "$ROOT/web/index.html"
echo 'FEDERATIONBANK STAFF WIRE UI PROJECTION SHELL: OK'
