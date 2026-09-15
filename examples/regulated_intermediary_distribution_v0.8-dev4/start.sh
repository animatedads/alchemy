#!/usr/bin/env bash
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
MODE="preview"
HTTP_HOST="${RID_HTTP_HOST:-127.0.0.1}"
HTTP_PORT="${RID_HTTP_PORT:-8082}"
GATEWAY_HOST="${RID_GATEWAY_HOST:-127.0.0.1}"
GATEWAY_PORT="${RID_GATEWAY_PORT:-8090}"
GATEWAY_TOKEN="${RID_GATEWAY_TOKEN:-rid-browser-token}"

usage() {
  cat <<USAGE
Usage: ./start.sh [--preview|--live] [--host HOST] [--port PORT]

  --preview   Start the sample-data Federation Intermediary UI (default).
              Uses Node's built-in HTTP server implementation in tools/.
  --live      Start the ooRexx development fixture, Queue Fabric Web Gateway,
              and the live server-authoritative RID browser UI.
  --host      HTTP bind host (default: ${HTTP_HOST})
  --port      HTTP UI port (default: ${HTTP_PORT})
  --help      Show this help.

Live mode requires the same dependency environment as run_browser_tests.sh:
  ALCHEMY_SRC CRYPTO_SRC QUEUE_FABRIC_SRC RUNTIME_REFERENCE_SRC
  WIRE_UI_SERVER_SRC WIRE_UI_BUILDER_SRC WEB_GATEWAY_ROOT
  ACCESS_PERMISSIONS_SRC SECURITY_EFFECT_SRC POLICY_SRC
and an ooRexx executable available as REXX_BIN (default: rexx).

This launcher never invokes Python.
USAGE
}

while (($#)); do
  case "$1" in
    --preview) MODE="preview"; shift ;;
    --live) MODE="live"; shift ;;
    --host) HTTP_HOST="${2:?--host requires a value}"; shift 2 ;;
    --port) HTTP_PORT="${2:?--port requires a value}"; shift 2 ;;
    --help|-h) usage; exit 0 ;;
    *) echo "Unknown argument: $1" >&2; usage >&2; exit 2 ;;
  esac
done

command -v node >/dev/null 2>&1 || { echo "Node.js is required; Python is deliberately not used by this launcher." >&2; exit 3; }

if [[ "$MODE" == "preview" ]]; then
  exec node "$HERE/tools/rid-ui-server.mjs" \
    --root "$HERE/web" --entry ui-preview.html --host "$HTTP_HOST" --port "$HTTP_PORT"
fi

REXX_BIN="${REXX_BIN:-rexx}"
command -v "$REXX_BIN" >/dev/null 2>&1 || { echo "Live mode requires ooRexx ('${REXX_BIN}'). Use ./start.sh for the static preview." >&2; exit 4; }

required=(ALCHEMY_SRC CRYPTO_SRC QUEUE_FABRIC_SRC RUNTIME_REFERENCE_SRC WIRE_UI_SERVER_SRC WIRE_UI_BUILDER_SRC WEB_GATEWAY_ROOT ACCESS_PERMISSIONS_SRC SECURITY_EFFECT_SRC POLICY_SRC)
missing=()
for name in "${required[@]}"; do [[ -n "${!name:-}" ]] || missing+=("$name"); done
if ((${#missing[@]})); then
  echo "Live mode is missing dependency environment variables:" >&2
  printf '  %s\n' "${missing[@]}" >&2
  echo "See README.md / run_browser_tests.sh. The launcher will not fall back to Python or a fake live backend." >&2
  exit 5
fi

TMP="$(mktemp -d "${TMPDIR:-/tmp}/rid-live.XXXXXX")"
PORT_FILE="$TMP/bridge.port"
STOP_FILE="$TMP/backend.stop"
RESULT_FILE="$TMP/backend.result.json"
BACKEND_LOG="$TMP/backend.log"
GATEWAY_LOG="$TMP/gateway.log"
BACKEND_PID=""
GATEWAY_PID=""
UI_PID=""

cleanup() {
  touch "$STOP_FILE" 2>/dev/null || true
  [[ -n "$UI_PID" ]] && kill "$UI_PID" 2>/dev/null || true
  [[ -n "$GATEWAY_PID" ]] && kill "$GATEWAY_PID" 2>/dev/null || true
  [[ -n "$BACKEND_PID" ]] && kill "$BACKEND_PID" 2>/dev/null || true
  [[ -n "$UI_PID" ]] && wait "$UI_PID" 2>/dev/null || true
  [[ -n "$GATEWAY_PID" ]] && wait "$GATEWAY_PID" 2>/dev/null || true
  [[ -n "$BACKEND_PID" ]] && wait "$BACKEND_PID" 2>/dev/null || true
  rm -rf "$TMP"
}
trap cleanup EXIT INT TERM

export REXX_PATH="$HERE/src:$HERE/examples:$HERE/integration:$HERE/tests:$WIRE_UI_SERVER_SRC:$WIRE_UI_BUILDER_SRC:$WEB_GATEWAY_ROOT/src:$ACCESS_PERMISSIONS_SRC:$SECURITY_EFFECT_SRC:$POLICY_SRC:$ALCHEMY_SRC:$CRYPTO_SRC:$QUEUE_FABRIC_SRC:$RUNTIME_REFERENCE_SRC${REXX_PATH:+:$REXX_PATH}"

"$REXX_BIN" "$HERE/tests/rid_web_backend_fixture.rex" "$PORT_FILE" "$STOP_FILE" "$RESULT_FILE" >"$BACKEND_LOG" 2>&1 &
BACKEND_PID=$!
for _ in $(seq 1 600); do
  [[ -s "$PORT_FILE" ]] && break
  if ! kill -0 "$BACKEND_PID" 2>/dev/null; then
    echo "RID ooRexx backend exited during startup:" >&2; cat "$BACKEND_LOG" >&2; exit 6
  fi
  sleep 0.05
done
[[ -s "$PORT_FILE" ]] || { echo "RID ooRexx backend did not publish its bridge port." >&2; cat "$BACKEND_LOG" >&2; exit 7; }
BRIDGE_PORT="$(tr -d '[:space:]' < "$PORT_FILE")"

export QF_BRIDGE_HOST="127.0.0.1"
export QF_BRIDGE_PORT="$BRIDGE_PORT"
export QF_BRIDGE_TOKEN="bridge-secret"
export WIRE_UI_INBOUND_QUEUE="WIREUI.IN.WEB"
export WIRE_UI_GATEWAY_HOST="$GATEWAY_HOST"
export WIRE_UI_GATEWAY_PORT="$GATEWAY_PORT"
export WIRE_UI_GATEWAY_PATH="/wire-ui"
export WIRE_UI_GATEWAY_PATH_TOKEN="$GATEWAY_TOKEN"
node "$WEB_GATEWAY_ROOT/node/gateway.mjs" >"$GATEWAY_LOG" 2>&1 &
GATEWAY_PID=$!

for _ in $(seq 1 200); do
  if grep -q 'wire-ui-gateway-listening' "$GATEWAY_LOG" 2>/dev/null; then break; fi
  if ! kill -0 "$GATEWAY_PID" 2>/dev/null; then
    echo "Queue Fabric Web Gateway exited during startup:" >&2; cat "$GATEWAY_LOG" >&2; exit 8
  fi
  sleep 0.05
done
grep -q 'wire-ui-gateway-listening' "$GATEWAY_LOG" 2>/dev/null || { echo "Queue Fabric Web Gateway did not become ready." >&2; cat "$GATEWAY_LOG" >&2; exit 9; }

GATEWAY_URL="ws://${GATEWAY_HOST}:${GATEWAY_PORT}/wire-ui?token=${GATEWAY_TOKEN}"
echo "RID live development fixture is ready."
echo "Backend bridge: 127.0.0.1:${BRIDGE_PORT}"
echo "WebSocket gateway: ${GATEWAY_URL}"
node "$HERE/tools/rid-ui-server.mjs" \
  --root "$HERE/web" --entry index.html --host "$HTTP_HOST" --port "$HTTP_PORT" \
  --gateway-url "$GATEWAY_URL" --access-point-id WEB --application-id RID-APP --session-id RID-BROWSER &
UI_PID=$!
wait "$UI_PID"
