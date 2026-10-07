#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
REXX_BIN="${REXX_BIN:-rexx}"
command -v "$REXX_BIN" >/dev/null 2>&1 || { echo "FAIL: ooRexx executable '$REXX_BIN' not found"; exit 20; }

: "${SOCKET_PROVIDER_SRC:?SOCKET_PROVIDER_SRC must point to ooRexx Socket Provider src (dev7 qualified baseline)}"
: "${INTENTION_SERVICE_SRC:?INTENTION_SERVICE_SRC must point to ooRexx Intention Service src (dev11 qualified baseline)}"

export REXX_PATH="$ROOT/src:$ROOT/providers/xmpp:$SOCKET_PROVIDER_SRC:$INTENTION_SERVICE_SRC${REXX_PATH:+:$REXX_PATH}"
"$REXX_BIN" -v || true
cd "$ROOT/tests"
"$REXX_BIN" test_core_objects.rex
"$REXX_BIN" test_access_classes.rex
"$REXX_BIN" test_dynamic_provider_discovery.rex
"$REXX_BIN" test_xmpp_projection.rex
"$REXX_BIN" test_xmpp_socket_isolation.rex
"$REXX_BIN" test_intention_discovery.rex

echo "PASS: Messaging & Presence semantic/provider/intention/socket-isolation qualification"

if [[ "${RUN_LIVE_XMPP:-0}" == "1" ]]; then
  echo "FAIL: dev1 intentionally has no bundled live RFC 6120 session engine."
  echo "Provide a registered standards-qualified XmppSession implementation before live qualification."
  exit 30
fi
