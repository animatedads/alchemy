#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
node --check "$ROOT/tools/aji-authoritative-host.mjs"
node --check "$ROOT/tools/aji-full-live-host.mjs"
"$ROOT/tests/test_projection_shell.sh"
"$ROOT/tests/test_preview_boundary.sh"
"$ROOT/tests/test_authoritative_boundary.sh"
"$ROOT/tests/test_starter.sh"
if [[ -n "${AJI_OOREXX:-}" && -n "${AJI_OOREXX_LIB:-}" ]]; then
  node "$ROOT/tests/test_authoritative_live_roundtrip.mjs"
else
  echo 'AJI authoritative live roundtrip: SKIP (set AJI_OOREXX and AJI_OOREXX_LIB)'
fi
if [[ -n "${AJI_OOREXX:-}" && -n "${AJI_OOREXX_LIB:-}" && -n "${WIRE_UI_BUILDER_ROOT:-}" && -n "${WIRE_UI_SERVER_ROOT:-}" && -n "${ALCHEMY_OBJECTS_ROOT:-}" && -n "${OOREXX_CRYPTO_ROOT:-}" ]]; then
  "$ROOT/tests/test_builder_server_contract.sh"
else
  echo 'AJI Builder -> Server contract: SKIP (set AJI_OOREXX, AJI_OOREXX_LIB, WIRE_UI_BUILDER_ROOT, WIRE_UI_SERVER_ROOT, ALCHEMY_OBJECTS_ROOT, OOREXX_CRYPTO_ROOT)'
fi
echo 'ALL JAPAN INSURANCE WIRE UI WEB v0.2: PASS'
