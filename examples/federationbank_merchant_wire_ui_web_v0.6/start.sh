#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"

MODE="${MERCHANT_WIRE_UI_MODE:-auto}"
HOST="${MERCHANT_WIRE_UI_HOST:-127.0.0.1}"
PORT="${MERCHANT_WIRE_UI_PORT:-8080}"
BOOTSTRAP_URL="${MERCHANT_WIRE_UI_BOOTSTRAP_URL:-}"
BOOTSTRAP_FILE="${MERCHANT_WIRE_UI_BOOTSTRAP_FILE:-}"
WIRE_UI_JS_ROOT="${ALCHEMY_WIRE_UI_JS_ROOT:-}"
CHECK_ONLY=0

usage() {
  cat <<'USAGE'
Usage: ./start.sh [options]

Canonical package-root launcher for FederationBank Merchant Wire UI.

With no arguments it starts the non-authoritative visual preview so a fresh
checkout is immediately inspectable.  For the real Wire UI framework, use
--live with either a server bootstrap URL or a browser-safe bootstrap file.

Options:
  --preview                 Start the visual fixture (default without live config)
  --live                    Start the live Wire UI projection shell
  --bootstrap-url URL       Proxy this authoritative Wire UI bootstrap URL
  --bootstrap-file FILE     Serve this browser-safe bootstrap JSON
  --wire-ui-js-root DIR     Serve the real Alchemy Wire UI JS module from DIR
  --host HOST               Listen host (default 127.0.0.1)
  --port PORT               Listen port (default 8080; 0 = ephemeral)
  --check                   Validate starter/runtime prerequisites and exit
  -h, --help                Show this help

Environment equivalents:
  MERCHANT_WIRE_UI_MODE
  MERCHANT_WIRE_UI_HOST
  MERCHANT_WIRE_UI_PORT
  MERCHANT_WIRE_UI_BOOTSTRAP_URL
  MERCHANT_WIRE_UI_BOOTSTRAP_FILE
  ALCHEMY_WIRE_UI_JS_ROOT

Examples:
  ./start.sh

  ./start.sh --live \
    --bootstrap-url http://127.0.0.1:8090/wire-ui/bootstrap \
    --wire-ui-js-root ../alchemy_wire_ui_js_v0.4-dev4

The launcher owns the local web plumbing; Codex/user should not start separate
ad-hoc HTTP servers for this package.
USAGE
}

while (($#)); do
  case "$1" in
    --preview) MODE=preview ;;
    --live) MODE=live ;;
    --bootstrap-url) shift; BOOTSTRAP_URL="${1:?--bootstrap-url requires URL}" ;;
    --bootstrap-file) shift; BOOTSTRAP_FILE="${1:?--bootstrap-file requires FILE}" ;;
    --wire-ui-js-root) shift; WIRE_UI_JS_ROOT="${1:?--wire-ui-js-root requires DIR}" ;;
    --host) shift; HOST="${1:?--host requires HOST}" ;;
    --port) shift; PORT="${1:?--port requires PORT}" ;;
    --check) CHECK_ONLY=1 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown option: $1" >&2; usage >&2; exit 2 ;;
  esac
  shift
done

command -v node >/dev/null 2>&1 || { echo 'node is required' >&2; exit 3; }
[[ -f "$ROOT/web/index.html" ]] || { echo 'web/index.html missing' >&2; exit 3; }
[[ -f "$ROOT/web/preview.html" ]] || { echo 'web/preview.html missing' >&2; exit 3; }
[[ -f "$ROOT/tools/merchant-dev-server.mjs" ]] || { echo 'starter runtime missing' >&2; exit 3; }

if [[ "$MODE" == auto ]]; then
  if [[ -n "$BOOTSTRAP_URL" || -n "$BOOTSTRAP_FILE" ]]; then MODE=live; else MODE=preview; fi
fi
if [[ "$MODE" != preview && "$MODE" != live ]]; then
  echo "MERCHANT_WIRE_UI_MODE must be auto, preview or live" >&2; exit 2
fi
if [[ -n "$BOOTSTRAP_URL" && -n "$BOOTSTRAP_FILE" ]]; then
  echo 'Use either bootstrap URL or bootstrap file, not both' >&2; exit 2
fi
if [[ "$MODE" == live && -z "$BOOTSTRAP_URL" && -z "$BOOTSTRAP_FILE" ]]; then
  echo 'Live mode requires --bootstrap-url or --bootstrap-file' >&2; exit 2
fi
if [[ -n "$BOOTSTRAP_FILE" ]]; then
  [[ "$BOOTSTRAP_FILE" = /* ]] || BOOTSTRAP_FILE="$PWD/$BOOTSTRAP_FILE"
  [[ -f "$BOOTSTRAP_FILE" ]] || { echo "bootstrap file not found: $BOOTSTRAP_FILE" >&2; exit 3; }
fi
if [[ -n "$WIRE_UI_JS_ROOT" ]]; then
  [[ "$WIRE_UI_JS_ROOT" = /* ]] || WIRE_UI_JS_ROOT="$PWD/$WIRE_UI_JS_ROOT"
  [[ -f "$WIRE_UI_JS_ROOT/src/index.js" ]] || { echo "Wire UI runtime src/index.js not found under: $WIRE_UI_JS_ROOT" >&2; exit 3; }
fi

if ((CHECK_ONLY)); then
  echo "FederationBank Merchant Wire UI starter: PASS mode=$MODE"
  exit 0
fi

args=(--mode "$MODE" --host "$HOST" --port "$PORT")
[[ -n "$BOOTSTRAP_URL" ]] && args+=(--bootstrap-url "$BOOTSTRAP_URL")
[[ -n "$BOOTSTRAP_FILE" ]] && args+=(--bootstrap-file "$BOOTSTRAP_FILE")
[[ -n "$WIRE_UI_JS_ROOT" ]] && args+=(--wire-ui-js-root "$WIRE_UI_JS_ROOT")

exec node "$ROOT/tools/merchant-dev-server.mjs" "${args[@]}"
