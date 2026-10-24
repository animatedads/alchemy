#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
REXX_BIN="${REXX_BIN:-rexx}"
command -v "$REXX_BIN" >/dev/null 2>&1 || { echo "FAIL: ooRexx executable '$REXX_BIN' not found"; exit 20; }

: "${SOCKET_PROVIDER_SRC:?SOCKET_PROVIDER_SRC must point to the exact ooRexx Socket Provider source under qualification (current external baseline dev16)}"
: "${INTENTION_SERVICE_SRC:?INTENTION_SERVICE_SRC must point to ooRexx Intention Service src (dev11 qualified baseline)}"
: "${INSTRUMENTATION_MESH_SRC:?INSTRUMENTATION_MESH_SRC must point to the exact ooRexx Instrumentation Mesh source under qualification (current external baseline dev8)}"

export REXX_PATH="$ROOT/src:$ROOT/providers/xmpp:$SOCKET_PROVIDER_SRC:$INTENTION_SERVICE_SRC:$INSTRUMENTATION_MESH_SRC${REXX_PATH:+:$REXX_PATH}"
"$REXX_BIN" -v || true
cd "$ROOT/tests"
for test in test_core_objects.rex test_access_classes.rex test_dynamic_provider_discovery.rex test_xmpp_projection.rex test_xmpp_socket_isolation.rex test_xmpp_socket_provider_current.rex test_xmpp_stream_framer.rex test_xmpp_session_handshake.rex test_xmpp_session_fail_closed.rex test_xmpp_session_events.rex test_intention_discovery.rex test_intention_dispatch.rex test_extension_registry.rex test_instrumentation_mesh.rex
do
  "$REXX_BIN" "$test"
done
echo "PASS: Messaging & Presence semantic/provider/intention/plugin/XMPP-session/socket-isolation/instrumentation qualification"
if [[ "${RUN_LIVE_XMPP:-0}" == "1" ]]; then
  echo "FAIL: live RFC 6120 qualification is intentionally blocked on the recorded lower STARTTLS boundary."
  exit 30
fi
