#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# The browser remains projection-only. Development fixture data is server-side.
if grep -Eiq 'AJI-HOME-2026-018441|AJI-CAR-2026-006712|AJI-PI-2026-001904|fixturePolicies|assessedPayableMinor.*780000' "$ROOT/web/index.html" "$ROOT/web/aji-wire-ui.js" "$ROOT/web/bootstrap-config.js"; then
  echo 'FAIL: authoritative fixture/business data leaked into live browser shell' >&2; exit 1
fi
grep -q 'AJIWireUIApplication subclass WireUIApplication' "$ROOT/runtime/aji_wire_ui_backend.rex"
grep -q 'WireUIWebAccessPointBinding' "$ROOT/runtime/aji_wire_ui_backend.rex"
grep -q 'AUTHORITATIVE_DEVELOPMENT_FIXTURE' "$ROOT/runtime/aji_wire_ui_backend.rex"
grep -q 'BILLING' "$ROOT/runtime/aji_wire_ui_backend.rex"
echo 'AJI authoritative-service boundary: OK'
