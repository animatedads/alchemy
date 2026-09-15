#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
node --check "$ROOT/web/bootstrap-config.js"
node --check "$ROOT/web/aji-wire-ui.js"
node --test "$ROOT/tests/test_bootstrap_config.mjs"
# Live shell must remain presentation/transport only: no AJI business command or money arithmetic.
if grep -Eiq 'calculatePremium|rateRisk|assessClaim|reserveMinor|postJournal|debitAccount|creditAccount|BILLING_CASH_RECEIVED|POLICY_PREMIUM_ADJUSTED|CLAIM_PAID|NON_PAYMENT' "$ROOT/web/index.html" "$ROOT/web/aji-wire-ui.js"; then
  echo 'FAIL: live browser shell contains AJI business semantics' >&2; exit 1
fi
grep -q 'QueueFabricGatewayTransport' "$ROOT/web/aji-wire-ui.js"
grep -q 'MaterialController' "$ROOT/web/aji-wire-ui.js"
grep -q "putResultMode: 'required'" "$ROOT/web/aji-wire-ui.js"
grep -q 'ALL_JAPAN_INSURANCE' "$ROOT/web/aji-wire-ui.js"
grep -q 'wire-ui-root' "$ROOT/web/index.html"
echo 'AJI WIRE UI PROJECTION SHELL: OK'
